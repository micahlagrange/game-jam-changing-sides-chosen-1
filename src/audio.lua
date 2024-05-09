require('src.soundmanager')

local Audio = {}

local currentBGM
local files = {
    mainTheme = 'sfx/Changing_sides.wav',
    eliteZeroes = 'sfx/Elite_Zeroes.wav'
}

function Audio.playSFX(name)
    love.audio.play(files[name])
end

function Audio.playBGM(name)
    Audio.stopMusic()
    currentBGM = love.audio.play(files[name], 'stream', true)
    return name
end

function Audio.stopMusic()
    love.audio.stop(currentBGM)
end

function Audio.update()
    love.audio.update()
end

return Audio
