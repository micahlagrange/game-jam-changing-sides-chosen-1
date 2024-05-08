local tween = require 'libs.tween' -- Include the tween library
local object = require('libs.classic')

local objects = {}

local explod_anim = object:extend()
function explod_anim:new(ex, ey, maxSize, color, duration)
    self.duration = duration
    self.circle = { size = 0 }
    self.position = { x = ex, y = ey }
    self.maxSize = maxSize * SCALE
    self.color = color
    self.alpha = .5
    self.tween = tween.new(self.duration, self.circle, { size = self.maxSize }, tween.easing.outQuad)
end

function explod_anim:update(dt)
    self.alpha = self.alpha - .02
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
function Explosions.new(x, y, maxSize, color, duration)
    if not duration then duration = .3 end
    if not maxSize then maxSize = 100 end
    table.insert(objects, explod_anim(x, y, maxSize, color, duration))
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
    for _, e in ipairs(objects) do
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], e.alpha)
        love.graphics.circle('fill',
            e.position.x * CELL_SIZE + (CELL_SIZE / 2),
            e.position.y * CELL_SIZE + (CELL_SIZE / 2),
            e.circle.size,
            e.circle.size,
            e.circle.size)
    end
end

return Explosions
