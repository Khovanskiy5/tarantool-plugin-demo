-- Тесты расчёта заказов. Правый клик → Run строит дерево результатов;
-- эти же функции удобно разбирать в графическом отладчике на живом
-- инстансе (DEMO.md, раздел 10).
local test_dir = debug.getinfo(1, 'S').source:match('^@(.+)/[^/]+$') or '.'
package.path = table.concat({
    test_dir .. '/../src/?.lua',
    test_dir .. '/../src/?/init.lua',
    package.path,
}, ';')

local t = require('luatest')
local orders = require('model.orders')

local g = t.group('orders')

local function order(id, items)
    return { id = id, user_id = 1, items = items }
end

g.test_subtotal_sums_positions = function()
    local sum = orders.subtotal({
        { sku = 'A', title = 'Кофе', price = 100, qty = 2 },
        { sku = 'B', title = 'Чай', price = 50.5, qty = 4 },
    })
    t.assert_equals(sum, 402)
end

g.test_small_order_gets_welcome_discount_only = function()
    local calculation = orders.calculate(order(1, {
        { sku = 'A', title = 'Кофе', price = 500, qty = 2 },
    }))
    t.assert_equals(calculation.subtotal, 1000)
    t.assert_equals(calculation.total, 950)
    t.assert_equals(#calculation.trace, 1)
    t.assert_equals(calculation.trace[1].rule, 'приветственная')
end

g.test_threshold_rules_apply_in_order = function()
    local calculation = orders.calculate(order(2, {
        { sku = 'A', title = 'Кофе', price = 2000, qty = 3 },
    }))
    -- 6000 → −5% = 5700 → «постоянный клиент» −300 = 5400
    t.assert_equals(calculation.total, 5400)
    t.assert_equals(calculation.trace[2].rule, 'постоянный клиент')
end

g.test_large_order_enters_nested_groups = function()
    local calculation = orders.calculate(order(3, {
        { sku = 'LAPTOP', title = 'Ноутбук', price = 129900, qty = 1 },
    }))
    local depths = {}
    for _, applied in ipairs(calculation.trace) do
        depths[applied.depth] = true
    end
    -- сработали правила всех трёх уровней дерева — это и видно в стеке отладчика
    t.assert_equals(depths[1], true)
    t.assert_equals(depths[2], true)
    t.assert_equals(depths[3], true)
    t.assert_gt(calculation.discount, 20000)
end

g.test_discount_never_exceeds_amount = function()
    local calculation = orders.calculate(order(4, {
        { sku = 'PIN', title = 'Значок', price = 10, qty = 1 },
    }))
    t.assert_gt(calculation.total, 0)
end
