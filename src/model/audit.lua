-- Журнал изменений спейса orders на триггере on_replace.
--
-- Точка останова внутри триггера — сценарий, который в консоли не отладишь:
-- триггер выполняется внутри чужой транзакции, в файбере того, кто пишет
-- (файбер запроса «pool», рабочий файбер очереди или админ-консоль).
-- Отладчик останавливает процесс в C-коде, не уступая файбер, поэтому
-- транзакция при этом не рвётся.
local fiber = require('fiber')
local log = require('log').new('audit')

local audit = {}

--- Триггер on_replace: old и new — таплы (cdata), поэтому в панели
--- переменных они пустые; рядом лежат before/after — те же данные
--- обычными таблицами.
---@param old box.tuple?
---@param new box.tuple?
---@param space string
---@param operation string  INSERT | REPLACE | UPDATE | DELETE
function audit.on_replace(old, new, space, operation)
    local actor = ('%s#%d'):format(fiber.self():name(), fiber.self():id())
    local before = old ~= nil and old:tomap({ names_only = true }) or nil
    local after = new ~= nil and new:tomap({ names_only = true }) or nil
    local changed = after or before

    local delta = 0
    if before ~= nil and after ~= nil then
        delta = (after.total_amount or 0) - (before.total_amount or 0)
    end

    box.space.order_events:insert({
        box.NULL,
        changed.id,
        operation,
        actor,
        delta,
        require('datetime').now(),
    })

    log.verbose('%s %s заказ %d (изменение суммы %.2f)', actor, operation, changed.id, delta)
end

--- Вешает триггер на спейс orders.
function audit.install()
    box.space.orders:on_replace(audit.on_replace)
    log.info('журнал изменений orders включён')
end

return audit
