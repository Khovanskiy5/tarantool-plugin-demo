-- Генератор нагрузки для графической отладки.
--
-- Запускается конфигурацией «Tarantool: нагрузка для отладки» и стучится
-- по iproto в storage-001-a. Пока инстанс стоит на точке останова, вызов
-- честно висит — это видно прямо в окне Run: строка «→ вызываю…» напечатана,
-- ответа нет. Нажали Resume — ответ появился.
--
-- Аргументы: [сценарий] [сколько]
--   checkout — синхронный расчёт в файбере запроса (по умолчанию)
--   queue    — заказ уходит в очередь, считает фоновый файбер
--   import   — пакетный импорт: несколько файберов сразу
--   all      — все три подряд
local netbox = require('net.box')
local json = require('json')

local URI = os.getenv('DEMO_URI') or 'client:secret@localhost:3311'
-- Таймаут заведомо большой: инстанс замирает, пока идёт разбор на точке останова.
local TIMEOUT = tonumber(os.getenv('DEMO_TIMEOUT')) or 600

local scenario = arg[1] or 'all'
local count = tonumber(arg[2]) or 3

local connection = netbox.connect(URI, { wait_connected = 5 })
if not connection:is_connected() then
    error(('нет соединения с %s — запущен ли кластер?'):format(URI))
end
print(('подключились к %s (%s)'):format(URI, connection.peer_uuid or 'ok'))

--- Вызов с печатью «до» и «после»: в окне Run видно, что клиент ждёт.
---@param name string
---@param args table
---@return any
local function call(name, args)
    print(('→ вызываю %s%s'):format(name, json.encode(args)))
    local started = require('clock').monotonic()
    local ok, result = pcall(connection.call, connection, name, args, { timeout = TIMEOUT })
    local elapsed = require('clock').monotonic() - started
    if not ok then
        print(('✗ %s: %s'):format(name, tostring(result)))
        return nil
    end
    print(('✓ %s за %.1f с: %s'):format(name, elapsed, json.encode(result)))
    return result
end

--- Заказ с предсказуемой суммой: чем больше номер, тем крупнее корзина.
--- Клиент говорит с инстансом только по iproto, поэтому серверные модули
--- ему не нужны — позиции собираются здесь же.
---@param order_id number
---@return table
local function make_order(order_id)
    return {
        id = order_id,
        user_id = 1 + order_id % 3,
        items = {
            { sku = 'COFFEE-250', title = 'Кофе в зёрнах', price = 1250.00, qty = 1 + order_id % 4 },
            { sku = 'TEA-100', title = 'Чай улун', price = 890.50, qty = 2 },
            { sku = 'CUP-01', title = 'Кружка', price = 450.00, qty = order_id % 3 },
        },
    }
end

--- Крупный заказ: сумма переваливает за 100 000, поэтому срабатывают
--- вложенные группы правил — в отладчике видно глубокую рекурсию,
--- а условная точка останова «amount > 100000» ловит только его.
---@param order_id number
---@return table
local function make_big_order(order_id)
    return {
        id = order_id,
        user_id = 1,
        items = {
            { sku = 'LAPTOP-16', title = 'Ноутбук', price = 129900.00, qty = 1 },
            { sku = 'COFFEE-250', title = 'Кофе в зёрнах', price = 1250.00, qty = 4 },
        },
    }
end

if scenario == 'big' or scenario == 'all' then
    print('\n— крупный заказ: глубокая рекурсия правил —')
    call('api.checkout', { make_big_order(900) })
end

if scenario == 'checkout' or scenario == 'all' then
    print('\n— синхронный расчёт (файбер запроса «pool») —')
    for index = 1, count do
        call('api.checkout', { make_order(500 + index) })
    end
end

if scenario == 'queue' or scenario == 'all' then
    print('\n— очередь (фоновые файберы order-worker-N) —')
    for index = 1, count do
        call('api.submit', { make_order(600 + index), TIMEOUT })
    end
end

if scenario == 'import' or scenario == 'all' then
    print('\n— пакетный импорт (файберы import-1…import-N) —')
    call('api.import', { count, 3, 700 })
end

print('\n— состояние инстанса —')
call('api.stats', {})

connection:close()
os.exit(0)
