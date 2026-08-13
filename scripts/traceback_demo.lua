-- Демо кликабельных трейсбеков: скрипт нарочно падает.
-- В выводе Run строки вида scripts/traceback_demo.lua:NN и users.lua:NN
-- становятся ссылками — клик открывает файл на нужной строке
-- (имя без каталога плагин разрешает поиском по индексу проекта).
local log = require('log')
local users = require('model.users')

log.info('лог до падения: такие строки Tarantool печатает как users.lua:NN')

local function middle_layer()
    users.explode()
end

local function top_layer()
    middle_layer()
end

top_layer()
