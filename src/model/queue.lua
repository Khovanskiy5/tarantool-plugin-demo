-- Очередь заказов на фоновых файберах.
--
-- Ради этого сценария отладчик и нужен: обработка идёт не в главном
-- файбере инстанса и не в файбере запроса, а в собственных файберах
-- order-worker-N. Точка останова в process() ловит именно их — видно
-- имя файбера, задачу и весь стек до fiber.create.
local fiber = require('fiber')
local log = require('log').new('queue')
local orders = require('model.orders')

local queue = {}

local CAPACITY = 128

local state = {
    channel = nil,
    workers = {},
    processed = 0,
    failed = 0,
}

--- Обработка одной задачи. Здесь удобно ставить точку останова:
--- останов происходит в файбере order-worker-N.
---@param job table  { order = Order, done = table? }
---@param worker string
---@return Calculation
local function process(job, worker)
    local order = job.order
    local calculation = orders.calculate(order)
    local tuple = orders.save(calculation)

    state.processed = state.processed + 1
    log.info('%s обработал заказ %d: итог %.2f (скидка %.2f), тапл %s',
        worker, calculation.order_id, calculation.total, calculation.discount, tostring(tuple))
    return calculation
end

--- Тело рабочего файбера: вечный цикл поверх канала.
---@param index number
local function worker_loop(index)
    local worker = ('order-worker-%d'):format(index)
    fiber.self():name(worker)
    log.info('%s запущен', worker)

    while true do
        local job = state.channel:get()
        if job ~= nil then
            local ok, result = pcall(process, job, worker)
            if not ok then
                state.failed = state.failed + 1
                log.error('%s не смог обработать заказ %s: %s',
                    worker, job.order and job.order.id, result)
            end
            if job.done ~= nil then
                job.done:put(ok and result or { error = tostring(result) }, 1)
            end
        end
    end
end

--- Поднимает канал и рабочие файберы. Вызывается один раз при старте.
---@param worker_count number
function queue.start(worker_count)
    if state.channel ~= nil then
        return
    end
    state.channel = fiber.channel(CAPACITY)
    for index = 1, (worker_count or 2) do
        state.workers[index] = fiber.create(worker_loop, index)
    end
end

--- Кладёт заказ в очередь. Если задан wait_seconds — дожидается расчёта
--- (клиент по iproto висит, пока фоновый файбер стоит на точке останова).
---@param order Order
---@param wait_seconds number?
---@return Calculation|table
function queue.submit(order, wait_seconds)
    local job = { order = order }
    if wait_seconds ~= nil then
        job.done = fiber.channel(1)
    end

    if not state.channel:put(job, 1) then
        error('очередь заполнена')
    end
    if job.done == nil then
        return { queued = order.id }
    end

    local result = job.done:get(wait_seconds)
    if result == nil then
        error(('расчёт заказа %d не завершился за %d с'):format(order.id, wait_seconds))
    end
    return result
end

---@return table
function queue.stats()
    return {
        workers = #state.workers,
        processed = state.processed,
        failed = state.failed,
        waiting = state.channel ~= nil and state.channel:count() or 0,
    }
end

return queue
