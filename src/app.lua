-- Точка входа приложения: config.yaml → app.file. Выполняется на каждом
-- инстансе кластера после применения конфигурации.

-- tt запускает инстанс с рабочим каталогом приложения, но подстрахуемся:
-- добавим src/ приложения в пути поиска модулей независимо от cwd.
local app_dir = debug.getinfo(1, 'S').source:match('^@(.+)/[^/]+$')
if app_dir then
    package.path = table.concat({
        app_dir .. '/?.lua',
        app_dir .. '/?/init.lua',
        package.path,
    }, ';')
end

-- Графический отладчик. Включается секцией app.cfg.debugger в config.yaml;
-- при выключенной секции обе строки не делают ничего, поэтому безопасны
-- в постоянном коде. Второй вызов — старый способ через TARANTOOL_DEBUG.
local debug_setup = require('debug_setup')
debug_setup.attach_if_configured()
debug_setup.attach_if_requested()

-- Глобальная функция D() для панели Watches отладчика: разворачивает
-- таплы и прочие cdata Tarantool в обычные таблицы.
require('inspect').install()

local fiber = require('fiber')
local log = require('log').new('demo')

local instance_name = box.info.name or 'unknown'
local replicaset = (box.info.replicaset or {}).name or 'unknown'

log.info('инстанс %s (репликасет %s) запускается', instance_name, replicaset)

-- Спейсы создаёт только лидер хранилища; роутер остаётся «пустым»,
-- а реплика получает данные по репликации.
local is_storage_leader = replicaset:match('^storage') ~= nil and not box.info.ro
if is_storage_leader then
    require('model.schema').bootstrap()

    -- Триггер журналирования вешаем только на лидере: на реплике он
    -- сработал бы ещё раз на реплицированных строках.
    require('model.audit').install()

    -- Фоновые обработчики заказов — файберы order-worker-1 и order-worker-2.
    require('model.queue').start(2)

    -- Функции, доступные клиенту по iproto: conn:call('api.checkout', …).
    rawset(_G, 'api', require('api'))
end

-- Фоновый файбер-«пульс»: живые строки в логах для панели Tarantool
-- и для демонстрации кликабельных ссылок вида app.lua:NN в журнале.
fiber.create(function()
    fiber.self():name('heartbeat')
    while true do
        log.info('пульс инстанса %s: uptime=%ds', instance_name, box.info.uptime)
        fiber.sleep(30)
    end
end)

log.info('инстанс %s готов', instance_name)
