-- Домен «заказы»: сумма позиций и дерево правил скидок.
--
-- Модуль устроен так, чтобы в отладчике было на что смотреть: вложенные
-- таблицы в панели переменных, рекурсия в стеке вызовов (несколько кадров
-- одной функции, у каждого свои значения) и переходы между модулями
-- по Step Into.
local log = require('log').new('orders')

local orders = {}

---@class OrderItem
---@field sku string    артикул
---@field title string  название
---@field price number  цена за единицу
---@field qty number    количество

---@class DiscountRule
---@field name string                      человекочитаемое имя правила
---@field kind 'percent'|'amount'|'group'  процент, фиксированная сумма, группа
---@field value number?                    размер скидки
---@field min_total number?                порог применения
---@field rules DiscountRule[]?            вложенные правила для kind = 'group'

---@class Order
---@field id number
---@field user_id number
---@field items OrderItem[]

---@class Calculation
---@field order_id number
---@field positions number
---@field subtotal number
---@field discount number
---@field total number
---@field trace table[]  какие правила сработали

--- Дерево правил скидок. Намеренно дерево, а не список: рекурсивный обход
--- даёт в отладчике стек из нескольких кадров apply_rules.
---@param order Order
---@return DiscountRule[]
function orders.rules_for(order)
    return {
        { name = 'приветственная', kind = 'percent', value = 5 },
        {
            name = 'корзина',
            kind = 'group',
            rules = {
                { name = 'от 10 000', kind = 'percent', value = 7, min_total = 10000 },
                {
                    name = 'крупный опт',
                    kind = 'group',
                    rules = {
                        { name = 'от 100 000', kind = 'percent', value = 10, min_total = 100000 },
                        { name = 'доставка в подарок', kind = 'amount', value = 500, min_total = 100000 },
                    },
                },
            },
        },
        { name = 'постоянный клиент', kind = 'amount', value = 300, min_total = 3000 },
    }
end

--- Сумма позиций без скидок.
---@param items OrderItem[]
---@return number
function orders.subtotal(items)
    local sum = 0
    for index, item in ipairs(items) do
        local line_total = item.price * item.qty
        sum = sum + line_total
        log.verbose('позиция %d: %s x%d = %.2f', index, item.title, item.qty, line_total)
    end
    return sum
end

--- Рекурсивно применяет дерево правил к сумме.
---@param rules DiscountRule[]
---@param amount number  сумма на входе в узел
---@param depth number   глубина рекурсии — видна в стеке отладчика
---@param trace table[]  журнал сработавших правил
---@return number
function orders.apply_rules(rules, amount, depth, trace)
    local current = amount
    for _, rule in ipairs(rules) do
        local applicable = rule.min_total == nil or current >= rule.min_total
        if rule.kind == 'group' then
            current = orders.apply_rules(rule.rules, current, depth + 1, trace)
        elseif applicable then
            local discount = rule.kind == 'percent'
                and current * rule.value / 100
                or math.min(rule.value, current)
            current = current - discount
            table.insert(trace, {
                rule = rule.name,
                depth = depth,
                discount = discount,
                rest = current,
            })
        end
    end
    return current
end

--- Полный расчёт заказа: сумма позиций → скидки → итог.
---@param order Order
---@return Calculation
function orders.calculate(order)
    local subtotal = orders.subtotal(order.items)
    local rules = orders.rules_for(order)
    local trace = {}
    local total = orders.apply_rules(rules, subtotal, 1, trace)

    local calculation = {
        order_id = order.id,
        user_id = order.user_id,
        positions = #order.items,
        subtotal = subtotal,
        discount = math.floor((subtotal - total) * 100 + 0.5) / 100,
        total = math.floor(total * 100 + 0.5) / 100,
        trace = trace,
    }
    return calculation
end

--- Записывает результат расчёта в спейс orders.
---@param calculation Calculation
---@return box.tuple
function orders.save(calculation)
    local datetime = require('datetime')
    return box.space.orders:replace({
        calculation.order_id,
        calculation.user_id,
        calculation.total,
        datetime.now(),
    })
end

--- Демонстрационный набор позиций: qty зависит от номера заказа,
--- поэтому суммы разные — удобно для условных точек останова.
---@param order_id number
---@return OrderItem[]
function orders.demo_items(order_id)
    return {
        { sku = 'COFFEE-250', title = 'Кофе в зёрнах', price = 1250.00, qty = 1 + order_id % 4 },
        { sku = 'TEA-100', title = 'Чай улун', price = 890.50, qty = 2 },
        { sku = 'CUP-01', title = 'Кружка', price = 450.00, qty = order_id % 3 },
    }
end

return orders
