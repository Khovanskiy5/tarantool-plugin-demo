-- Демо конфигурации запуска «Tarantool»: правый клик по файлу → Run.
-- Работает require('model.users') — флажок LUA_PATH в конфигурации
-- добавляет корень проекта и src/ в пути поиска модулей.
local users = require('model.users')

print('Привет от Tarantool ' .. _TARANTOOL .. '!')

local demo_users = {
    { id = 1, name = 'Алиса Селезнёва', email = 'alice@example.com' },
    { id = 2, name = 'Боб Марли', email = 'bob@example.com' },
    { id = 3, name = 'Некто Ошибочный', email = 'не-адрес' },
}

for _, u in ipairs(demo_users) do
    local valid, err = users.validate(u)
    if valid then
        print('✔ ' .. users.format(valid))
    else
        print('✘ пользователь отклонён: ' .. err)
    end
end

-- Аргументы конфигурации запуска приходят в глобальную таблицу arg.
if #arg > 0 then
    print('аргументы запуска: ' .. table.concat(arg, ' '))
end

os.exit(0)
