require('src.soundmanager')

math.randomseed(os.time())

local interruptSfxSource
local Audio = {}
local currentBGM
local pauseTimer = 0

local files = {
    mainTheme = 'sfx/Changing_Sides.wav',
    eliteZeroes = 'sfx/Elite_Zeroes.wav',
    footStep = {
        'sfx/foot step1.mp3',
        'sfx/foot step2.mp3',
        'sfx/foot step3.mp3',
        'sfx/foot step4.mp3',
        'sfx/foot step5.mp3'
    },
    enemyDie = { 'sfx/Attacking_Total_Zeroes1.wav',
        'sfx/Attacking_Total_Zeroes2.wav' },
    achievement = 'sfx/achievement.mp3'
}

function Audio.playSFX(name)
    if type(files[name]) == 'table' then
        local idx = love.math.random(#files[name])
        local file = files[name][idx]
        return love.audio.play(file, 'static', false)
    end
    return love.audio.play(files[name], 'static', false)
end

function Audio.playBGM(name)
    Audio.stopMusic()
    currentBGM = love.audio.play(files[name], 'stream', true)
    return name
end

function Audio.stopMusic()
    love.audio.stop(currentBGM)
end

function Audio.update(dt)
    love.audio.update()

    if pauseTimer > 0 then
        print(pauseTimer)
        pauseTimer = pauseTimer - dt
        if pauseTimer <= 0 then
            currentBGM:play()
        end
    end
end

function Audio.interruptMusicSFX(name)
    currentBGM:pause()
    interruptSfxSource = Audio.playSFX(name)
    if not interruptSfxSource then return end
    pauseTimer = interruptSfxSource:getDuration()
end

return Audio
