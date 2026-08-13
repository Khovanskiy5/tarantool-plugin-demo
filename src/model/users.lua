-- Модуль домена «пользователи»: чистые функции, работают и в скрипте,
-- и внутри инстанса. Демонстрирует require('model.users') через LUA_PATH
-- конфигурации запуска (плагин добавляет корень проекта и src/).
local users = {}

local EMAIL_PATTERN = '^[%w%.%_%-]+@[%w%.%-]+%.%a%a+$'

function users.validate(user)
    if type(user) ~= 'table' then
        return nil, 'пользователь должен быть таблицей'
    end
    if type(user.id) ~= 'number' or user.id < 1 then
        return nil, 'id должен быть положительным числом'
    end
    if type(user.name) ~= 'string' or #user.name == 0 then
        return nil, 'имя не может быть пустым'
    end
    if type(user.email) ~= 'string' or not user.email:match(EMAIL_PATTERN) then
        return nil, ('некорректный email: %s'):format(tostring(user.email))
    end
    return user
end

function users.format(user)
    return ('#%d %s <%s>'):format(user.id, user.name, user.email)
end

-- Нарочно падающая функция — для демонстрации кликабельного трейсбека:
-- ссылка users.lua:NN в выводе Run откроет это место в редакторе.
function users.explode()
    error('демонстрационная ошибка из model.users')
end

return users
