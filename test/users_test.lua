-- Тесты luatest: правый клик по файлу → Run — плагин построит дерево
-- результатов из TAP-вывода. Имена *_test.lua и test_*.lua распознаются
-- автоматически.
-- luatest не добавляет каталоги проекта в package.path — расширяем
-- сами относительно расположения этого файла, чтобы работать
-- и из IDE, и из терминала при любом рабочем каталоге.
local test_dir = debug.getinfo(1, 'S').source:match('^@(.+)/[^/]+$') or '.'
package.path = table.concat({
    test_dir .. '/../src/?.lua',
    test_dir .. '/../src/?/init.lua',
    package.path,
}, ';')

local t = require('luatest')
local users = require('model.users')

local g = t.group('users')

g.test_valid_user_passes = function()
    local user, err = users.validate({
        id = 1,
        name = 'Алиса Селезнёва',
        email = 'alice@example.com',
    })
    t.assert_equals(err, nil)
    t.assert_equals(user.name, 'Алиса Селезнёва')
end

g.test_empty_name_rejected = function()
    local user, err = users.validate({ id = 1, name = '', email = 'a@b.io' })
    t.assert_equals(user, nil)
    t.assert_str_contains(err, 'имя')
end

g.test_bad_email_rejected = function()
    local user, err = users.validate({ id = 1, name = 'Боб', email = 'нет' })
    t.assert_equals(user, nil)
    t.assert_str_contains(err, 'email')
end

g.test_bad_id_rejected = function()
    local user, err = users.validate({ id = -5, name = 'Боб', email = 'a@b.io' })
    t.assert_equals(user, nil)
    t.assert_str_contains(err, 'id')
end

g.test_format = function()
    local line = users.format({ id = 7, name = 'Грета', email = 'g@ex.com' })
    t.assert_equals(line, '#7 Грета <g@ex.com>')
end
