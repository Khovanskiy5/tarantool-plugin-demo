-- Функции, которые клиент вызывает по iproto: conn:call('api.checkout', …).
--
-- Каждый такой вызов Tarantool исполняет в отдельном файбере пула
-- (в отладчике он называется «pool»), поэтому точка останова здесь
-- останавливает именно файбер запроса, а клиент на другом конце
-- соединения честно ждёт ответа, пока идёт разбор.
local fiber = require('fiber')
local log = require('log').new('api')
local orders = require('model.orders')
local queue = require('model.queue')

local api = {}

--- Кто исполняет текущий вызов: имя и номер файбера.
---@return string
local function current_fiber()
    return ('%s#%d'):format(fiber.self():name(), fiber.self():id())
end

--- Синхронный расчёт: считает и пишет заказ прямо в файбере запроса.
---@param order Order
---@return table
function api.checkout(order)
    local handler = current_fiber()
    local calculation = orders.calculate(order)
    local tuple = orders.save(calculation)

    log.info('%s посчитал заказ %d: %.2f', handler, order.id, calculation.total)
    return {
        handled_by = handler,
        calculation = calculation,
        saved = tuple:tomap({ names_only = true }),
    }
end

--- Асинхронный путь: заказ уходит в очередь, считает фоновый файбер.
--- Клиент ждёт результат, поэтому останов в файбере очереди видно и с его
--- стороны — вызов просто не возвращается, пока не нажат Resume.
---@param order Order
---@param wait_seconds number?
---@return table
function api.submit(order, wait_seconds)
    local caller = current_fiber()
    local calculation = queue.submit(order, wait_seconds or 60)
    return { requested_by = caller, calculation = calculation }
end

--- Пакетный импорт: на каждый пакет создаётся свой файбер.
--- Одна точка останова в import_batch срабатывает по очереди в файберах
--- import-1, import-2, … — в отладчике видно, что кадр стека каждый раз свой.
---@param batch_count number
---@param per_batch number
---@param base_id number?
---@return table
function api.import(batch_count, per_batch, base_id)
    local first_id = base_id or 1000
    local workers = {}

    for batch = 1, batch_count do
        local worker = fiber.new(api.import_batch, batch, per_batch, first_id + batch * 100)
        worker:set_joinable(true)
        workers[batch] = worker
    end

    local imported, failed = 0, 0
    for batch, worker in ipairs(workers) do
        local ok, count = worker:join()
        if ok then
            imported = imported + count
        else
            failed = failed + 1
            log.error('пакет %d не импортирован: %s', batch, count)
        end
    end

    return { batches = batch_count, imported = imported, failed = failed }
end

--- Тело файбера импорта: обрабатывает свой пакет заказов.
---@param batch number
---@param per_batch number
---@param base_id number
---@return number
function api.import_batch(batch, per_batch, base_id)
    fiber.self():name(('import-%d'):format(batch))
    local imported = 0

    for offset = 1, per_batch do
        local order_id = base_id + offset
        local order = {
            id = order_id,
            user_id = 1 + order_id % 3,
            items = orders.demo_items(order_id),
        }
        local calculation = orders.calculate(order)
        orders.save(calculation)
        imported = imported + 1
    end

    log.info('пакет %d импортировал %d заказов', batch, imported)
    return imported
end

--- Сводка состояния — удобно вызывать из консоли и из Watches.
---@return table
function api.stats()
    return {
        instance = box.info.name,
        read_only = box.info.ro,
        orders = box.space.orders:len(),
        events = box.space.order_events:len(),
        queue = queue.stats(),
    }
end

return api
