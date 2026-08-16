-- Минимальный пример «два бесконечных цикла с yield»: фоновый файбер
-- и главный. Точки останова ставятся в обоих — и срабатывают в обоих,
-- потому что отладочный хук LuaJIT общий для всей виртуальной машины,
-- а не привязан к корутине.
--
-- Запуск: конфигурация «Tarantool: два цикла с yield» → кнопка Debug.
-- Точки: строка 20 (тело фонового файбера) и строка 34 (тело главного).
-- Рабочий каталог конфигурации — var/, чтобы снимки box.cfg{} не сорили
-- в корне проекта.
local fiber = require('fiber')

box.cfg({})

fiber.create(function()
    fiber.name('background-loop')

    local iteration = 0

    while true do
        iteration = iteration + 1 -- точка останова: файбер background-loop
        fiber.yield()
    end
end)

local function main_iteration()
    fiber.yield()
end

fiber.name('main-loop')

local main_loop_iteration = 0

while true do
    main_loop_iteration = main_loop_iteration + 1 -- точка останова: главный файбер
    local ok, err = pcall(main_iteration)
    assert(ok, err)
end
