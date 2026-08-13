-- Песочница live-шаблонов: поставьте курсор на пустую строку, наберите
-- сокращение и нажмите Tab. Список: Settings → Editor → Live Templates →
-- Tarantool.
--
--   tspace  → box.schema.space.create + format + первичный индекс
--   tonce   → box.once('key', function() … end)
--   tfiber  → файбер с set_joinable и join
--   tatomic → box.atomic(function() … end)
--   tnetbox → подключение net.box + close
--   tlog    → именованный журнал require('log').new(…)
--   twatch  → триггер on_replace на спейсе
--
-- Пробуйте здесь:


local fiber = require('fiber')
local worker = fiber.new(function()

end)
worker:set_joinable(true)
local ok, result = worker:join()

box.space.users:on_replace(function(old, new, space_name, operation)
    
end)