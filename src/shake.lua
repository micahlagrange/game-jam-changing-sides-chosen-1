local Shake = {}

local t, shakeDuration, shakeMagnitude = 0, -1, 0
function Shake.startShake(duration, magnitude)
    magnitude = magnitude or (5 * SCALE)
    t, shakeDuration, shakeMagnitude = 0, duration or 1, magnitude
end

function Shake.update(dt)
    if t < shakeDuration then
        t = t + dt
    end
end

function Shake.draw()
    if t < shakeDuration then
        local dx = love.math.random(-shakeMagnitude, shakeMagnitude)
        local dy = love.math.random(-shakeMagnitude, shakeMagnitude)
        love.graphics.translate(dx, dy)
    end
end

return Shake
