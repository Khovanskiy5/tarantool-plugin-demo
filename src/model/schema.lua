-- Схема данных инстанса-хранилища. Спейсы получают format{...} —
-- только такие спейсы видны в SQL и в окне Database.
local log = require('log').new('schema')

local schema = {}

function schema.bootstrap()
    box.once('schema:v1', function()
        local users = box.schema.space.create('users', { if_not_exists = true })
        users:format({
            { name = 'id', type = 'unsigned' },
            { name = 'name', type = 'string' },
            { name = 'email', type = 'string' },
            { name = 'city', type = 'string', is_nullable = true },
        })
        users:create_index('primary', { parts = { 'id' }, if_not_exists = true })
        users:create_index('email', {
            parts = { 'email' },
            unique = true,
            if_not_exists = true,
        })

        users:insert({ 1, 'Алиса Селезнёва', 'alice@example.com', 'Москва' })
        users:insert({ 2, 'Боб Марли', 'bob@example.com', 'Кингстон' })
        users:insert({ 3, 'Григорий Перельман', 'grisha@example.com', 'Санкт-Петербург' })

        log.info('спейс users создан и наполнен демо-данными')
    end)

    box.once('schema:v1-orders', function()
        local orders = box.schema.space.create('orders', { if_not_exists = true })
        orders:format({
            { name = 'id', type = 'unsigned' },
            { name = 'user_id', type = 'unsigned' },
            { name = 'total_amount', type = 'number' },
            { name = 'created_at', type = 'datetime', is_nullable = true },
        })
        orders:create_index('primary', { parts = { 'id' }, if_not_exists = true })
        orders:create_index('by_user', {
            parts = { 'user_id' },
            unique = false,
            if_not_exists = true,
        })

        local datetime = require('datetime')
        orders:insert({ 1, 1, 990.50, datetime.now() })
        orders:insert({ 2, 1, 149.00, datetime.now() })
        orders:insert({ 3, 2, 4200.00, datetime.now() })

        log.info('спейс orders создан и наполнен демо-данными')
    end)

    -- Журнал изменений заказов: сюда пишет триггер on_replace (model.audit).
    box.once('schema:v1-order-events', function()
        box.schema.sequence.create('order_events_seq', { if_not_exists = true })

        local events = box.schema.space.create('order_events', { if_not_exists = true })
        events:format({
            { name = 'id', type = 'unsigned' },
            { name = 'order_id', type = 'unsigned' },
            { name = 'operation', type = 'string' },
            { name = 'actor', type = 'string' },
            { name = 'delta', type = 'number' },
            { name = 'at', type = 'datetime' },
        })
        events:create_index('primary', {
            parts = { 'id' },
            sequence = 'order_events_seq',
            if_not_exists = true,
        })
        events:create_index('by_order', {
            parts = { 'order_id' },
            unique = false,
            if_not_exists = true,
        })

        log.info('спейс order_events создан')
    end)
end

return schema
