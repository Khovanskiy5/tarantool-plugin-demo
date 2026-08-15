-- Помощник для панелей Variables и Watches графического отладчика.
--
-- Отладчик EmmyLua показывает cdata пустым значением, а всё интересное
-- в Tarantool — именно cdata: тапл, decimal, uuid, datetime, interval,
-- объект ошибки. Функция D() разворачивает их в обычные таблицы и строки,
-- которые панель Variables рисует деревом:
--
--     D(tuple)                         --> { id = 1, name = 'Алиса', … }
--     D(box.space.users:select())      --> массив таблиц
--     D(box.error.last())              --> { code = …, message = … }
--
-- Вызывать удобнее всего из списка Watches; в коде она не нужна.
local M = {}

local MAX_DEPTH = 5
local MAX_ITEMS = 200

local convert

--- Разворачивает тапл в таблицу с именами полей, если у спейса задан format.
---@param tuple box.tuple
---@param depth number
---@return table
local function convert_tuple(tuple, depth)
    local ok, map = pcall(tuple.tomap, tuple, { names_only = true })
    if ok and next(map) ~= nil then
        return convert(map, depth + 1)
    end
    return convert(tuple:totable(), depth + 1)
end

---@param value any
---@param depth number
---@return any
function convert(value, depth)
    if depth > MAX_DEPTH then
        return '…'
    end

    local kind = type(value)
    if kind == 'cdata' then
        if box.tuple.is(value) then
            return convert_tuple(value, depth)
        end
        -- объект ошибки Tarantool разворачивается методом unpack
        local unpacked_ok, unpacked = pcall(function() return value:unpack() end)
        if unpacked_ok and type(unpacked) == 'table' then
            unpacked.trace = nil -- трассировка в панели только шумит
            return convert(unpacked, depth + 1)
        end
        -- decimal, uuid, datetime, interval: у всех есть __tostring
        local text_ok, text = pcall(tostring, value)
        return text_ok and text or '<cdata>'
    end

    if kind ~= 'table' then
        return value
    end

    local copy = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > MAX_ITEMS then
            copy['…'] = ('показаны первые %d элементов'):format(MAX_ITEMS)
            break
        end
        copy[convert(key, depth + 1)] = convert(item, depth + 1)
    end
    return copy
end

--- Разворачивает любое значение Tarantool в вид, пригодный для панели
--- переменных отладчика.
---@param value any
---@return any
function M.inspect(value)
    local ok, result = pcall(convert, value, 1)
    return ok and result or ('<не удалось развернуть: %s>'):format(result)
end

--- Кладёт inspect в глобальную функцию D — чтобы в Watches писать «D(tuple)».
function M.install()
    rawset(_G, 'D', M.inspect)
end

return M
