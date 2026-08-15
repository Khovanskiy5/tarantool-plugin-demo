-- Включение графического отладчика по секции app.cfg.debugger из config.yaml.
--
-- Сам отладчик поднимает emmy_debug.lua, который плагин кладёт в корень
-- проекта (Tools → Настроить Emmy-отладчик Tarantool): он находит нативную
-- библиотеку emmy_core в установленной IDE и открывает порт.
--
-- Здесь решается только вопрос «включать или нет». Раньше для этого нужна
-- была переменная окружения TARANTOOL_DEBUG, то есть запуск кластера из
-- терминала. Через app.cfg отладку включает сам config.yaml — со схемой,
-- автодополнением и валидацией, — а кластер поднимается кнопкой
-- «Запустить» в панели Tarantool.
local log = require('log').new('debug')

local M = {}

--- Секция app.cfg.debugger из кластерной конфигурации.
---@return table?
local function read_settings()
    local ok_module, config = pcall(require, 'config')
    if not ok_module then
        return nil
    end
    local ok_value, app_cfg = pcall(config.get, config, 'app.cfg')
    if not ok_value or app_cfg == nil then
        return nil
    end
    return app_cfg.debugger
end

--- Открывает порт отладчика, если он разрешён конфигурацией.
--- В кластере порт открывает ровно один инстанс: остальные боролись бы
--- за тот же порт, поэтому имя инстанса указывается явно.
---@return boolean
function M.attach_if_configured()
    local settings = read_settings()
    if settings == nil or settings.enabled ~= true then
        return false
    end
    if settings.instance ~= nil and settings.instance ~= box.info.name then
        return false
    end

    local ok_module, emmy = pcall(require, 'emmy_debug')
    if not ok_module then
        log.warn('emmy_debug.lua не найден — выполните Tools → Настроить Emmy-отладчик Tarantool')
        return false
    end

    local port = settings.port or 9966
    local ok, err = emmy.attach({ host = settings.host, port = port })
    if ok then
        log.info('отладчик слушает порт %d: подключайтесь конфигурацией «Tarantool: attach debugger»', port)
    else
        log.warn('отладчик не запущен: %s', err)
    end
    return ok
end

--- Старый способ включения — переменная окружения TARANTOOL_DEBUG.
--- Оставлен для запусков вне IDE.
function M.attach_if_requested()
    local ok_module, emmy = pcall(require, 'emmy_debug')
    if ok_module then
        emmy.attach_if_requested()
    end
end

return M
