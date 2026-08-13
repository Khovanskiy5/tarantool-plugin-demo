-- Демо встроенного отладчика: в конфигурации запуска «Tarantool»
-- включите флажок «Запустить со встроенным отладчиком (tarantool -d)».
-- Скрипт стартует под консолью luadebug в окне Run: команды help, n (шаг),
-- s (шаг внутрь), p <выражение> (печать), b <файл:строка> (точка останова).
local users = require('model.users')

local total = 0

local function accumulate(user)
    local weight = #user.name -- посмотрите значение: p weight
    total = total + weight
    return weight
end

local roster = {
    { id = 1, name = 'Алиса Селезнёва', email = 'alice@example.com' },
    { id = 2, name = 'Боб Марли', email = 'bob@example.com' },
}

for i, user in ipairs(roster) do
    local weight = accumulate(user)
    print(('%d. %s → вес имени %d, накоплено %d'):format(
        i, users.format(user), weight, total))
end

print('итого: ' .. total)
os.exit(0)
