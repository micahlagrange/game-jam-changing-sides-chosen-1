local tween = require 'libs.tween' -- Include the tween library
local object = require('libs.classic')

local objects = {}

local explod_anim = object:extend()
function explod_anim:new(ex, ey, maxSize)
    self.circle = { size = 0 }
    self.position = { x = ex, y = ey }
    self.maxSize = maxSize * SCALE
    self.alpha = .8
    self.tween = tween.new(.5, self.circle, { size = self.maxSize }, tween.easing.outQuad)
end

function explod_anim:update(dt)
    print(dt)
    self.alpha = self.alpha - .08
    return self.tween:update(dt)
end

local function cleanUp(dt)
    for i, explod in ipairs(objects) do
        if explod:update(dt) then
            table.remove(objects, i)
        end
    end
end

local Explosions = {}
function Explosions.new(x, y, maxSize)
    if not maxSize then maxSize = 100 end
    table.insert(objects, explod_anim(x, y, maxSize))
end

-- In your update function, update the tween
function Explosions.update(dt)
    for _, explod in pairs(objects) do
        explod:update(dt)
        cleanUp(dt)
    end
end

-- In your draw function, you can use the tweened property
function Explosions.draw()
    for _, explod in ipairs(objects) do
        love.graphics.setColor(1, 0, 0, explod.alpha)
        love.graphics.circle('fill',
            explod.position.x * CELL_SIZE + (CELL_SIZE / 2),
            explod.position.y * CELL_SIZE + (CELL_SIZE / 2),
            explod.circle.size,
            explod.circle.size,
            explod.circle.size)
    end
end

return Explosions
