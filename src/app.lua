-- Точка входа приложения: config.yaml → app.file. Выполняется на каждом
-- инстансе кластера после применения конфигурации.
--
-- Строка ниже — для Emmy-отладчика (Tools → Настроить Emmy-отладчик
-- Tarantool). Без переменной окружения TARANTOOL_DEBUG она не делает
-- ничего, поэтому безопасна в постоянном коде.
local ok_dbg, emmy = pcall(require, 'emmy_debug')
if ok_dbg then
    emmy.attach_if_requested()
end

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

local fiber = require('fiber')
local log = require('log').new('demo')

local instance_name = box.info.name or 'unknown'
local replicaset = (box.info.replicaset or {}).name or 'unknown'

log.info('инстанс %s (репликасет %s) запускается', instance_name, replicaset)

-- Спейсы создаёт только лидер хранилища; роутер остаётся «пустым»,
-- а реплика получает данные по репликации.
if replicaset:match('^storage') and not box.info.ro then
    require('model.schema').bootstrap()
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
