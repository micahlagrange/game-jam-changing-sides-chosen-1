local Luafinding = require("libs.luafinding")
local Vector = require("libs.vector")
local Explosions = require("src.explosion")
local Audio = require('src.audio')
local Shake = require("src.shake")
-- local debug = require("src.debug")

require("src.chars")

math.randomseed(os.time())
love.graphics.setDefaultFilter("nearest", "nearest")
love.window.setMode(WINDOW_WIDTH * SCALE, WINDOW_HEIGHT * SCALE)

CHOSEN_1_CHARACTER = "1"
GROUND_CHARACTERS = { ".", ",", "'" }
ENEMY_CHARACTER = "0"
MAIN_CHARACTER = "@"
AMMO_CHARACTER = "*"

COLOR_AMMO = { .6, .2, .7 }
COLOR_BG_OTHERSIDE = { .1, .1, .3 }
COLOR_BG_MAIN = { .1, .1, .1 }
COLOR_CHOSEN_1 = { 0.91, 0.855, 0.584 }
COLOR_ENEMY_CHARACTERS = { 1, 1, 1 }
COLOR_BOSS_CHARACTERS = { 1, .1, .1 }
COLOR_ENEMY_EXPLOSION = { 0.929, 0.408, 0.102 }
COLOR_GUI_TEXT = { 0, 1, 0.976 }
COLOR_GROUND = { 0.165, .5, 0.29 }
COLOR_MAIN_CHAR = { 0, 1, 0 }
COLOR_MAIN_CHAR_EXPLOSION = { 0.624, 0.929, 0.102 }
COLOR_MENU_TEXT = { .5, .7, .4 }
COLOR_MENU_BOX_BORDER_EASY = { 0, 1, 0 }
COLOR_MENU_BOX_BORDER_NORMAL = { .1, .3, .3 }
COLOR_MENU_BOX_BORDER_HARD = { .5, .2, .2 }
COLOR_MENU_BOX_BORDER_EXTREME = { 1, 0, 0 }
COLOR_MENU_BOX = { .1, .2, .3 }
COLOR_NOTIFICATION_TEXT = { 1, .5, .4 }
COLOR_NOTIFICATION_BOX = { .8, .8, .6 }
COLOR_SUBTLE_HINT = { .1, .5, .5 }
COLOR_WARNING_TEXT = { 1, .2, .4 }

SAVE_SCORE_FILE = ".highscore.c1d"
SAVE_ACHIEVEMENTS_FILE = ".achievements.c1d"
HURT_DELAY = .3
INPUT_DELAY = 1
NOTIFICATION_DELAY = 3
WEB_OS = "Web"

DIFFICULTY = {}
DIFFICULTY.Easy = "boring"
DIFFICULTY.NORMAL = "Normal"
DIFFICULTY.HARD = "HARD"
DIFFICULTY.EXTREME = "P!=NP"
DIFFICULTY[4] = DIFFICULTY.Easy
DIFFICULTY[3] = DIFFICULTY.NORMAL
DIFFICULTY[2] = DIFFICULTY.HARD
DIFFICULTY[1] = DIFFICULTY.EXTREME

-- left side of screen
local registry = {}
local diagonalable = false
local grid = {}
local gridWidth = 7
local gridHeight = 5
-- right side of screen
local otherRegistry = {}
local otherGrid = {}
local otherWidth = 5
local otherHeight = 5
-- game state
local ammo = {}
local achievementsEarned = {}
local claimedChosen1 = false
local chosen1Location = {}
local currentPlayerRegistry = registry
local currentPlayerGrid = grid
local currentPlayerColor = { COLOR_MAIN_CHAR }
local currentBGM
local difficultySetting = 3
local fontCache = {}
local fontCurrent = 1
local gameLevel = 1
local gameResettable = false
local highScoreDefeated = false
local hurtTimer = 0
local inputtable = true
local inputTimer = 0
local notificationTimer = 0
local notificationText = ""
local playerHp = difficultySetting
local playable = false
local points = 0
local previousHighScore = {}

previousHighScore[1] = 0
previousHighScore[2] = 0
previousHighScore[3] = 0
previousHighScore[4] = 0

local function highScoreSaveFileName()
    return "difficulty" .. difficultySetting .. SAVE_SCORE_FILE
end

local function achievementsSaveFileName()
    return "difficulty" .. difficultySetting .. SAVE_ACHIEVEMENTS_FILE
end

local function cycleDifficulty(direction)
    if not direction then direction = 1 end
    if direction < 1 then direction = -1 end

    difficultySetting = difficultySetting + direction
    if difficultySetting == 0 then
        difficultySetting = 4
    end
    if difficultySetting == 5 then
        difficultySetting = 1
    end
    playerHp = difficultySetting
    LoadHighScore()
end

local function equalCoords(coords, otherCoords)
    return coords.x == otherCoords.x and coords.y == otherCoords.y
end

local function fillFromRegistry(theGrid, width, height, theRegistry)
    for col = 1, width do
        theGrid[col] = {}
        for row = 1, height do
            theGrid[col][row] = theRegistry[col][row]
        end
    end
end

local function findAllInNeighbors(char)
    local foundNeighbors = {}
    local neighbooringCells = {
        { x = POS.x,     y = POS.y + 1 },
        { x = POS.x,     y = POS.y - 1 },
        { x = POS.x + 1, y = POS.y },
        { x = POS.x - 1, y = POS.y },
    }
    local diagonalCells = {
        { x = POS.x + 1, y = POS.y + 1 },
        { x = POS.x + 1, y = POS.y - 1 },
        { x = POS.x - 1, y = POS.y - 1 },
        { x = POS.x - 1, y = POS.y + 1 },
    }
    if #ammo > 0 then
        for i = 1, #diagonalCells, 1 do
            table.insert(neighbooringCells, diagonalCells[i])
        end
    end
    for _, coord in ipairs(neighbooringCells) do
        if currentPlayerRegistry[coord.x] and currentPlayerRegistry[coord.x][coord.y] then
            if currentPlayerRegistry[coord.x][coord.y] == char then
                table.insert(foundNeighbors, coord)
            end
        end
    end
    return foundNeighbors
end

local function findAllInRegistry(theRegistry, char)
    local foundCoords = {}
    for fx, col in pairs(theRegistry) do
        for fy, regChar in pairs(col) do
            if regChar == char then
                table.insert(foundCoords, { x = fx, y = fy })
            end
        end
    end
    return foundCoords
end

local function getPlayerGridBounds()
    if currentPlayerGrid == grid then
        return gridWidth, gridHeight
    elseif currentPlayerGrid == otherGrid then
        return otherWidth, otherHeight
    else
        return gridWidth, gridHeight
    end
end

local function isCellNeighbor(playerPos, cellPos)
    if playerPos.x == cellPos.x and playerPos.y == cellPos.y then return true end
    local dx = math.abs(playerPos.x - cellPos.x)
    local dy = math.abs(playerPos.y - cellPos.y)
    -- Check if the cell is a neighbor
    if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) then
        return true
    end
    return false
end

local function getRandomElement(array)
    return array[love.math.random(#array)]
end

local function cleanRegistryOf(theRegistry, character, coords)
    for fx, col in pairs(theRegistry) do
        for fy, regChar in pairs(col) do
            if regChar == character then
                theRegistry[fx][fy] = getRandomElement(GROUND_CHARACTERS)
            end
        end
    end
    theRegistry[coords.x][coords.y] = character
end

local function initRegistry(theRegistry, width, height)
    -- fill the registry with ground cells
    for col = 1, width do
        theRegistry[col] = {}
        for row = 1, height do
            theRegistry[col][row] = getRandomElement(GROUND_CHARACTERS)
        end
    end
end

local function toVector(coords)
    return Vector(coords.x, coords.y)
end

local function bigFont(font)
    return font == 'commodore64.ttf' or font == 'papyrus.ttf'
end

local function centerOfCell(theGrid, col, row)
    assert(theGrid ~= nil, "theGrid may not be nil")
    assert(col ~= nil, "col may not be nil")
    assert(row ~= nil, "row may not be nil")
    -- Calculate the center of the cell
    local x = (col + 0.5) * CELL_SIZE
    local y = (row + 0.25) * CELL_SIZE
    -- Get the width and height of the character
    local textWidth = love.graphics.getFont():getWidth(".")
    -- Adjust the position of the character to center it in the cell
    local textX = x - (textWidth / 2)
    local textY = y
    return textX, textY
end

local function drawGrid(theGrid, width, height, bgColor, textColor, start)
    if not start then start = 0 end
    for col = 1, width do
        for row = 1, height do
            -- background
            love.graphics.setColor(bgColor)
            love.graphics.rectangle("fill", (start + col) * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(textColor)
            local textX, textY = centerOfCell(theGrid, col, row)
            love.graphics.print(theGrid[col][row], textX + (start * CELL_SIZE), textY)
            -- color the character
            DrawMainCharacter()
            -- color the enemies
            DrawEnemies()
            -- color the chosen 1
            DrawChosen1()
            -- color the ammo
            DrawAmmo()
        end
    end
end

local function drawBox(startCoords, endCoords, color)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill",
        startCoords.x, startCoords.y,
        endCoords.x, endCoords.y
    )
end

local function offsetBoxStart(coords, size)
    if not size then size = .5 end
    return {
        x = coords.x + (size * CELL_SIZE),
        y = coords.y + (size * CELL_SIZE)
    }
end

local function offsetBoxEnd(coords, size)
    if not size then size = 1 end
    return {
        x = coords.x - (size * CELL_SIZE),
        y = coords.y - (size * CELL_SIZE)
    }
end

local function niceBox(borderStartCoords, borderEndCoords, borderColor, innerColor, borderSize)
    if not borderSize then borderSize = .5 end
    drawBox(borderStartCoords, borderEndCoords, borderColor)
    drawBox(offsetBoxStart(borderStartCoords, borderSize), offsetBoxEnd(borderEndCoords, borderSize * 2), innerColor)
end

local function kill(array, theRegistry, enemyKill)
    local explosionColor = COLOR_ENEMY_EXPLOSION
    if #ammo > 0 then
        explosionColor = COLOR_AMMO
    end
    if theRegistry == nil then theRegistry = registry end
    if array == nil then return end
    -- aka kill
    for _, enemy in ipairs(array) do
        -- literally smash them into the GROUND lol
        theRegistry[enemy.x][enemy.y] = getRandomElement(GROUND_CHARACTERS)
        if enemyKill then
            points = points + 1
            Audio.playSFX('enemyDie')
            Shake.startShake(.1, 1)
            Explosions.new(enemy.x, enemy.y, 20, explosionColor, .5)
        end
    end
    if #array >= 4 and enemyKill then
        if GetAchievement("papyrus.ttf") then
            ShowNotification("QUADRAKILL [font unlock!]")
        end
    end
    if #array >= 5 and enemyKill then
        if GetAchievement("white-rabbit.TTF") then
            ShowNotification("PENTAKILL [font unlock!]")
        end
    end
    if #array >= 7 and enemyKill then
        if GetAchievement("SyukriaRegular.ttf") then
            ShowNotification("SEPTAKILL [font unlock!]")
        end
    end
end


function MoveCharacterInRegistry(registeredTo, character, oldPos, newPos)
    assert(registeredTo ~= nil, "registeredTo may not be nil")
    assert(character ~= nil, "character may not be nil")
    assert(oldPos ~= nil, "oldPos may not be nil")
    assert(newPos ~= nil, "newPos may not be nil")
    assert(newPos.x ~= nil, "newPos.x may not be nil")
    assert(newPos.y ~= nil, "newPos.y may not be nil")
    -- delete old character pos
    if registeredTo[oldPos.x] and registeredTo[oldPos.x][oldPos.y] == character then
        registeredTo[oldPos.x][oldPos.y] = getRandomElement(GROUND_CHARACTERS)
    end
    -- set new character pos
    Audio.playSFX("footStep")
    registeredTo[newPos.x][newPos.y] = character
end

function love.keyreleased(k)
    if k == "f" then CycleFont() end
    if k == "escape" and love.system.getOS() ~= WEB_OS then
        love.event.quit()
    end
    if not playable then
        if k == "left" or k == "down" then cycleDifficulty() end
        if k == "right" or k == "up" then cycleDifficulty(-1) end
        if k == "return" or k == "kpenter" and inputtable then
            playable = true
        end
        return
    end
    if gameResettable then
        if k == "f1" then
            ResetGame()
        end
        return
    elseif claimedChosen1 then
        if (k == "return" or k == "kpenter") and inputtable then
            claimedChosen1 = false
            TeleportTo(registry, grid, otherRegistry, { x = 1, y = 1 })
            PlaceMainCharacter()
            MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, POS)
            PlaceChosen1()
            GenerateAmmo()
            GenerateEnemies()
            if gameLevel % 5 == 4 then
                otherRegistry[chosen1Location.x][chosen1Location.y + 1] = AMMO_CHARACTER
                otherRegistry[chosen1Location.x + 1][chosen1Location.y + 1] = AMMO_CHARACTER
                otherRegistry[chosen1Location.x - 1][chosen1Location.y + 1] = AMMO_CHARACTER
            end
            local divisor = 2              -- normal difficultySetting
            if difficultySetting == 4 then -- easiest
                divisor = 2
            end
            if difficultySetting == 1 then -- hardest difficultySetting
                divisor = 4
            end
            playerHp = difficultySetting + math.floor(gameLevel / divisor)
        end
        return
    end
    local vector = {}
    if #ammo > 0 then
        if k == "e" or k == "pageup" or k == "kp9" then
            vector.x = POS.x + 1
            vector.y = POS.y - 1
        elseif k == "c" or k == "pagedown" or k == "kp3" then
            vector.x = POS.x + 1
            vector.y = POS.y + 1
        elseif k == "z" or k == "end" or k == "kp1" then
            vector.x = POS.x - 1
            vector.y = POS.y + 1
        elseif k == "q" or k == "home" or k == "kp7" then
            vector.x = POS.x - 1
            vector.y = POS.y - 1
        end
    end
    if k == "up" or k == "w" or k == "kp8" then
        vector.x = POS.x
        vector.y = POS.y - 1
    elseif k == "down" or k == "s" or k == "kp2" then
        vector.x = POS.x
        vector.y = POS.y + 1
    elseif k == "left" or k == "a" or k == "kp4" then
        vector.x = POS.x - 1
        vector.y = POS.y
    elseif k == "right" or k == "d" or k == "kp6" then
        vector.x = POS.x + 1
        vector.y = POS.y
    elseif k == "space" or k == "lctrl" or k == "rctrl" or k == "kp0" then
        if currentPlayerRegistry == registry then
            Explosions.new(POS.x + .15, POS.y, 10, COLOR_MAIN_CHAR_EXPLOSION)
            local neighbors = findAllInNeighbors(ENEMY_CHARACTER)
            if #neighbors >= 1 then
                if #ammo > 0 then
                    UseAmmo()
                end
                kill(neighbors, registry, true)
            end
        end
    end
    local xlimit, ylimit = getPlayerGridBounds()
    local oldPos = { x = POS.x, y = POS.y }
    if vector.x and vector.y then
        if IsAmmo(vector) then
            AddAmmo()
        end
        if currentPlayerRegistry == otherRegistry and IsTheChosen1(vector) then
            LevelEnd()
            return
        end
        if IsNotObstacle(vector, xlimit, ylimit) then
            POS.x = vector.x
            POS.y = vector.y
            MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, oldPos, POS)
            MoveEnemies()
        end
    end
end

function LevelEnd()
    gameLevel = gameLevel + 1
    if gameLevel < 5 then
        SetBGM("mainTheme")
    elseif gameLevel < 10 then
        SetBGM("asteriskStar")
    elseif gameLevel > 10 then
        SetBGM("weeb")
    end
    if gameLevel == 3 then
        if GetAchievement("commodore64.ttf") then
            ShowNotification("PewPew [font unlock!]")
        end
    elseif gameLevel == 7 then
        if GetAchievement("DwarfFortress.ttf") then
            ShowNotification("7 Dwarves [font unlock!]")
        end
    elseif gameLevel % 5 == 4 then
        inputTimer = INPUT_DELAY
        -- Audio.interruptMusicSFX('achievement')
    elseif gameLevel % 5 == 0 then
        inputTimer = INPUT_DELAY
        SetBGM("eliteZeroes")
        diagonalable = true
    else
        diagonalable = false
    end
    claimedChosen1 = true
    points = points + 1
    SaveAchievements()
end

function SetBGM(name)
    if currentBGM == name then return end
    Audio.playBGM(name)
    currentBGM = name
    print('Play ' .. name)
end

function love.load()
    CacheFonts()
    LoadAchievements()
    currentPlayerRegistry = registry
    currentPlayerGrid = grid
    LoadHighScore()
    playerHp = difficultySetting
    CycleFont(true)
    love.graphics.setFont(fontCache['AppleII.ttf'])
    initRegistry(registry, gridWidth, gridHeight)
    initRegistry(otherRegistry, otherWidth, otherHeight)
    -- put the main character in the middle of the grid
    chosen1Location = { x = math.floor(otherWidth / 2) + 1, y = math.floor(otherHeight / 2) + 1 }
    PlaceMainCharacter()
    currentPlayerRegistry[POS.x][POS.y] = MAIN_CHARACTER
    -- pre-fill the grid from registry
    fillFromRegistry(grid, gridWidth, gridHeight, registry)
    -- pre-fill the otherSideGrid from registry
    fillFromRegistry(otherGrid, otherWidth, otherHeight, otherRegistry)
    PlaceChosen1()
    GenerateEnemies()
    SetBGM("mainTheme")
end

function PlaceChosen1()
    otherRegistry[chosen1Location.x][chosen1Location.y] = CHOSEN_1_CHARACTER
end

function PlaceMainCharacter()
    POS = { x = math.ceil(gridWidth / 2), y = math.ceil(gridHeight / 2) }
end

function love.update(dt)
    Audio.update(dt)
    -- Fill the grid from registry
    for column = 1, gridWidth do
        for row = 1, gridHeight do
            grid[column][row] = registry[column][row]
        end
    end
    -- Fill the otherSideGrid from otherRegistry
    for column = 1, otherWidth do
        for row = 1, otherHeight do
            otherGrid[column][row] = otherRegistry[column][row]
        end
    end
    Explosions.update(dt)
    TickTimers(dt)
    Shake.update(dt)
    TeleportMaybe()
end

function LoadHighScore()
    if love.system.getOS() ~= WEB_OS then
        local saveData, _ = love.filesystem.read(highScoreSaveFileName())
        if saveData then previousHighScore[difficultySetting] = saveData else previousHighScore[difficultySetting] = 0 end
    else
        if points > previousHighScore[difficultySetting] then
            previousHighScore[difficultySetting] = points
            highScoreDefeated = true
        end
    end
end

function GetAmmoBar()
    local ammoBar = ""
    for _, am in ipairs(ammo) do
        ammoBar = ammoBar .. am
    end
    return ammoBar
end

function AddAmmo()
    table.insert(ammo, AMMO_CHARACTER)
end

function UseAmmo()
    if #ammo > 0 then
        table.remove(ammo, 1)
    end
end

function GetDifficulty()
    return DIFFICULTY[difficultySetting]
end

local function centeredTextPlacement(text)
    local textWidth = GetFont():getWidth(text)
    local start = (love.graphics.getWidth() / 2) - (textWidth / 2) - 1
    return start
end

local function rightOfScreenPlacement(text)
    local textWidth = GetFont():getWidth(text)
    local start = love.graphics.getWidth() - textWidth
    return start
end

local function bottomOfScreenPlacement(text)
    local textHeight = GetFont():getHeight(text)
    local start = love.graphics.getHeight() - textHeight
    return start
end

-- Draw the grid
function love.draw()
    -- HUD
    DrawGUIElement(
        GetAmmoBar(),
        rightOfScreenPlacement(GetAmmoBar()) - 10,
        10,
        COLOR_AMMO)
    DrawGUIElement("Charge:" .. playerHp
        .. " Level:" .. gameLevel
        .. " Points:" .. points,
        10,
        10,
        COLOR_GUI_TEXT)
    Shake.draw()
    -- RENDER THE MAIN GRID
    drawGrid(grid, gridWidth, gridHeight, COLOR_BG_MAIN, COLOR_GROUND)
    -- RENDER THE OTHER SIDE
    local otherGridStart = (gridWidth + 1)
    drawGrid(otherGrid, otherWidth, otherHeight, COLOR_BG_OTHERSIDE, COLOR_GROUND, otherGridStart)
    Explosions.draw()
    if playable and not gameResettable and not claimedChosen1 then
        local moveHint = ""
        if #ammo > 0 then moveHint = "  diagonally" end
        love.graphics.setColor(COLOR_GUI_TEXT)
        love.graphics.print("[space/ctrl]: attack" .. moveHint .. "\n"
            .. "[wasd]: move " .. moveHint .. "\n"
            .. " objective: collect a chosen 1",
            0,
            6 * CELL_SIZE + 10)
    end
    if not playable then
        local introText = "[enter]: New Game\n"
            .. "[arrowkeys]: Difficulty\n"
            .. "       { " .. GetDifficulty() .. " }\n\n"
            .. " High Score: "
            .. previousHighScore[difficultySetting]

        DrawMenu(introText)
    end

    if gameResettable then
        local congrats = " No congrats are in order"
            .. "\n Try to beat high score!"
            .. "\n Previous High Score:" .. previousHighScore[difficultySetting]
        local escapeClause = ""
        if highScoreDefeated then
            congrats = "\n     NEW HIGH SCORE!!\n"
                .. "Difficulty " .. GetDifficulty() .. "--> " .. points
        end
        if love.system.getOS() ~= WEB_OS then
            escapeClause = "[escape]:   Exit\n"
        end
        DrawMenu("[F1]: reset\n"
            .. escapeClause
            .. congrats,
            highScoreDefeated and COLOR_CHOSEN_1 or COLOR_MENU_TEXT)
    end

    if claimedChosen1 then
        local goNextLevelText = ""
        local warningText = nil
        if gameLevel % 5 == 4 then warningText = "Elite zeroes are\non their way" end
        if gameLevel == 7 then warningText = "qezc or numpad 1379\nmoves diagonally" end
        if diagonalable then
            warningText = "An upgraded zero swarm...\nTHEY ATTACK DIAGONALLY\n   pick up a *"
        end
        if inputtable then goNextLevelText = "[enter]: Go To Level " .. gameLevel end
        DrawMenu("CHOSEN 1 FOUND!!\n\n"
            .. goNextLevelText,
            nil,
            warningText)
    end
    DrawNotification()
end

function DrawGUIElement(text, x, y, color)
    if text == nil then return end
    if bigFont(GetFontName()) then text = string.lower(text) end
    love.graphics.setColor(color)
    love.graphics.print(text, x, y)
end

function MoveEnemies()
    local enemies = findAllInRegistry(registry, ENEMY_CHARACTER)
    for _, enemy in ipairs(enemies) do
        local oldPos = {}
        oldPos.x = enemy.x
        oldPos.y = enemy.y
        -- a star A* aStar AsTaR (ION?)
        local path = Luafinding(toVector(enemy), toVector(POS), grid, diagonalable):GetPath()
        if path and path[2] then
            local stepTo = path[2]
            if equalCoords(stepTo, POS) then
                HurtMainCharacter()
            else
                if IsNotObstacle(stepTo, gridWidth, gridHeight) and not IsAmmo(stepTo, true) then
                    enemy = stepTo
                    MoveCharacterInRegistry(registry, ENEMY_CHARACTER, oldPos, enemy)
                end
            end
        end
    end
end

function TickTimers(dt)
    if hurtTimer >= 0 then
        hurtTimer = hurtTimer - dt
        if hurtTimer <= 0 then
            currentPlayerColor = COLOR_MAIN_CHAR
        end
    end
    if notificationTimer >= 0 then
        notificationTimer = notificationTimer - dt
        if notificationTimer <= 0 then
            HideNotification()
        end
    end
    if inputTimer >= 0 then
        inputTimer = inputTimer - dt
        inputtable = false
    else
        inputtable = true
    end
end

function HideNotification()
    notificationText = ""
end

function ShowNotification(text, delay)
    local delay = delay or INPUT_DELAY
    if text == nil then return end
    if bigFont(GetFontName()) then text = string.lower(text) end
    inputTimer = delay
    notificationText = text
    notificationTimer = NOTIFICATION_DELAY
end

function DrawNotification()
    if notificationText ~= "" then
        niceBox({
                x = 1 * CELL_SIZE,
                y = bottomOfScreenPlacement(notificationText) - 1.5 * CELL_SIZE
            },
            {
                x = love.graphics.getWidth() - 2 * CELL_SIZE,
                y = 2 * CELL_SIZE
            },
            COLOR_MENU_BOX_BORDER_NORMAL,
            COLOR_NOTIFICATION_BOX,
            .3)
        love.graphics.setColor(COLOR_NOTIFICATION_TEXT)
        love.graphics.print(notificationText,
            2 * CELL_SIZE,
            bottomOfScreenPlacement(notificationText) - 1 * CELL_SIZE)
    end
end

function HurtMainCharacter()
    playerHp = playerHp - 1
    currentPlayerColor = { 1, 0, 0 }
    hurtTimer = HURT_DELAY
    Shake.startShake(.3, 5)
    if playerHp <= 0 then
        GameOver()
    end
end

function GenerateAmmo()
    local numAmmo
    local divisor = 2              -- normal mode
    if difficultySetting == 4 then -- easy
        divisor = 1
    end
    if difficultySetting == 1 then -- hard mode
        divisor = 3
    end

    numAmmo = gameLevel
    local maxAmmo = gameLevel / divisor
    if numAmmo > maxAmmo then
        numAmmo = maxAmmo
    end
    for _ = 1, numAmmo do
        local placementCandidate = {}
        while true do
            placementCandidate.x = math.random(gridWidth)
            placementCandidate.y = math.random(gridHeight)
            if not isCellNeighbor(POS, placementCandidate) and not isCellNeighbor(POS, placementCandidate) then
                registry[placementCandidate.x][placementCandidate.y] = AMMO_CHARACTER
                break
            end
        end
    end
end

function GenerateEnemies()
    local numEnemies = gameLevel
    local minEnemies = 1
    local maxEnemies = (gridHeight * gridWidth)
    if gameLevel < minEnemies then numEnemies = minEnemies end
    if diagonalable then
        numEnemies = numEnemies / 2
    end
    if numEnemies > maxEnemies then
        print("reached maximum number of enemies")
        numEnemies = maxEnemies
    end
    print("generating ", minEnemies + numEnemies, "enemies")
    for _ = 1, minEnemies + numEnemies do
        local placementCandidate = {}
        while true do
            placementCandidate.x = math.random(gridWidth)
            placementCandidate.y = math.random(gridHeight)
            if not isCellNeighbor(POS, placementCandidate) then
                registry[placementCandidate.x][placementCandidate.y] = ENEMY_CHARACTER
                break
            end
        end
    end
end

function IsNotObstacle(newPosition, xlimit, ylimit)
    assert(newPosition ~= nil)
    assert(type(xlimit) == "number")
    assert(type(ylimit) == "number")
    if newPosition.x > xlimit
        or newPosition.x < 1
        or newPosition.y > ylimit
        or newPosition.y < 1
    then
        return false
    end
    if registry[newPosition.x][newPosition.y] == ENEMY_CHARACTER then
        return false
    end
    return true
end

local function drawCharacter(character, theGrid, coords, color)
    love.graphics.setColor(color)
    local textX, textY = centerOfCell(theGrid, coords.x, coords.y)
    local otherGridStart = (gridWidth + 1)
    local start = 0
    if theGrid == otherGrid then
        start = otherGridStart
    end
    love.graphics.print(character, textX + (start * CELL_SIZE), textY)
end

function DrawMenu(text, textColor, warningText)
    if bigFont(GetFontName()) then
        if text ~= nil then
            text = string.lower(text)
        end
        if warningText ~= nil then
            warningText = string.lower(warningText)
        end
    end

    local borderColor = COLOR_MENU_BOX_BORDER_NORMAL
    if GetDifficulty() == DIFFICULTY.Easy then
        borderColor = COLOR_MENU_BOX_BORDER_EASY
    elseif GetDifficulty() == DIFFICULTY.HARD then
        borderColor = COLOR_MENU_BOX_BORDER_HARD
    elseif GetDifficulty() == DIFFICULTY.EXTREME then
        borderColor = COLOR_MENU_BOX_BORDER_EXTREME
    end

    if textColor == nil then textColor = COLOR_MENU_TEXT end
    niceBox({
            x = 1.5 * CELL_SIZE - (.5 * CELL_SIZE),
            y = 1.5 * CELL_SIZE - (.5 * CELL_SIZE)
        },
        {
            x = WINDOW_WIDTH * SCALE - (2 * CELL_SIZE),
            y = WINDOW_HEIGHT * SCALE - (2 * CELL_SIZE)
        },
        borderColor,
        COLOR_MENU_BOX)

    -- menu text
    love.graphics.setColor(textColor)
    love.graphics.print(text,
        2.5 * CELL_SIZE - (.5 * CELL_SIZE),
        (WINDOW_HEIGHT / 3.54) * SCALE)

    -- warning text
    if warningText then
        love.graphics.setColor(COLOR_WARNING_TEXT)
        love.graphics.print(warningText,
            2 * CELL_SIZE,
            WINDOW_HEIGHT * SCALE - 4 * CELL_SIZE)
    elseif #achievementsEarned > 0 then
        local fontHint = "[F]: cycle fonts"
        love.graphics.setColor(COLOR_SUBTLE_HINT)
        love.graphics.print(fontHint,
            2 * CELL_SIZE,
            WINDOW_HEIGHT * SCALE - 2.5 * CELL_SIZE)
    end
end

function SaveHighScore()
    local data = nil
    if love.system.getOS() ~= WEB_OS then
        data, _ = love.filesystem.read(highScoreSaveFileName())
        if data == nil then data = '0' end
        if points > tonumber(data) then
            love.filesystem.write(highScoreSaveFileName(), points)
            highScoreDefeated = true
        end
        LoadHighScore() -- do this so the var has it cached for other loops
    else
        if points > previousHighScore[difficultySetting] then
            previousHighScore[difficultySetting] = points
            highScoreDefeated = true
        end
    end
end

function GameOver()
    Audio.stopMusic()
    Audio.interruptMusicSFX("gameover")
    gameResettable = true
    SaveHighScore()
end

function ResetGame()
    points = 0
    highScoreDefeated = false
    gameResettable = false
    playable = true
    claimedChosen1 = false
    gameLevel = 1
    kill(findAllInRegistry(registry, ENEMY_CHARACTER), registry, false)
    TeleportTo(registry, grid, otherRegistry, { x = 1, y = 1 })
    love.load()
    MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, POS)
    ammo = {}
    playable = false
end

function DrawMainCharacter()
    drawCharacter(MAIN_CHARACTER, currentPlayerGrid, POS, currentPlayerColor)
end

function DrawChosen1()
    drawCharacter(CHOSEN_1_CHARACTER, otherGrid, chosen1Location, COLOR_CHOSEN_1)
end

function DrawEnemies()
    local color = COLOR_ENEMY_CHARACTERS
    if diagonalable then color = COLOR_BOSS_CHARACTERS end
    for _, enemy in pairs(findAllInRegistry(registry, ENEMY_CHARACTER)) do
        drawCharacter(ENEMY_CHARACTER, grid, enemy, color)
    end
end

function DrawAmmo()
    for _, ammos in pairs(findAllInRegistry(registry, AMMO_CHARACTER)) do
        drawCharacter(AMMO_CHARACTER, grid, ammos, COLOR_AMMO)
    end
    for _, ammos in pairs(findAllInRegistry(otherRegistry, AMMO_CHARACTER)) do
        drawCharacter(AMMO_CHARACTER, otherGrid, ammos, COLOR_AMMO)
    end
end

function TeleportTo(theRegistry, theGrid, oldRegistry, coords)
    if currentPlayerRegistry ~= theRegistry then
        currentPlayerRegistry = theRegistry
        currentPlayerGrid = theGrid
        kill({ POS }, oldRegistry)
        POS = coords
        MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, coords)
        cleanRegistryOf(theRegistry, MAIN_CHARACTER, POS)
    end
end

function TeleportMaybe()
    if #findAllInRegistry(registry, ENEMY_CHARACTER) <= 0 then
        TeleportTo(otherRegistry, otherGrid, registry, { x = 3, y = 5 })
    end
end

function IsTheChosen1(vector)
    return GetAtVector(otherRegistry, vector) == CHOSEN_1_CHARACTER
end

function IsAmmo(vector, isEnemy)
    if isEnemy then
        return GetAtVector(registry, vector) == AMMO_CHARACTER
    end

    return GetAtVector(registry, vector) == AMMO_CHARACTER
        or GetAtVector(otherRegistry, vector) == AMMO_CHARACTER
end

function GetAtVector(theRegistry, vector)
    if theRegistry[vector.x] and theRegistry[vector.x][vector.y] then
        return theRegistry[vector.x][vector.y]
    end
    return false
end

function GetFont()
    local fontNames = {}
    for k in pairs(fontCache) do
        table.insert(fontNames, k)
    end
    for i = 1, #fontNames do
        if i == fontCurrent then
            return fontCache[fontNames[i]]
        end
    end
end

function GetFontName()
    local fontNames = {}
    for k in pairs(fontCache) do
        table.insert(fontNames, k)
    end
    for i = 1, #fontNames do
        if i == fontCurrent then
            return fontNames[i]
        end
    end
end

function CycleFont(initial)
    if not initial then
        fontCurrent = fontCurrent + 1
    end
    local fontNames = {}
    for k in pairs(fontCache) do
        table.insert(fontNames, k)
    end
    if fontCurrent > #fontNames then fontCurrent = 1 end
    for i = 1, #fontNames do
        if i == fontCurrent then
            love.graphics.setFont(fontCache[fontNames[i]])
        end
    end
    if not initial then
        ShowNotification(GetFontName())
    end
end

function CacheFonts()
    local dir = "fonts/"
    local files = love.filesystem.getDirectoryItems(dir)
    for _, file in ipairs(files) do
        print(file)
        fontCache[file] = love.graphics.newFont(dir .. file, FONT_SIZE * SCALE)
    end
end

function AddFontToCache(fontFile)
    local dir = "achievementFonts/"
    fontCache[fontFile] = love.graphics.newFont(dir .. fontFile, FONT_SIZE * SCALE)
    love.graphics.setFont(fontCache[fontFile])
end

function GetAchievement(name)
    if achievementsEarned[name] == nil then
        Audio.interruptMusicSFX('achievement')
        achievementsEarned[name] = true
        AddFontToCache(name)
        return true
    end

    return false
end

local function splitString(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function deserialize(data)
    return splitString(data, ",")
end

local function serialize(table)
    local data = ""
    for ach in pairs(achievementsEarned) do
        data = data .. ach .. ","
    end
    return data
end

function SaveAchievements()
    if love.system.getOS() == WEB_OS then return end
    love.filesystem.write(achievementsSaveFileName(), serialize(achievementsEarned))
end

function LoadAchievements()
    if love.system.getOS() == WEB_OS then
        ShowNotification("Saving achievements/score\nworks only if downloaded!")
        return
    end
    local data = love.filesystem.read(achievementsSaveFileName())
    if data == nil then return end
    local achievementList = deserialize(data)
    for _, ach in ipairs(achievementList) do
        achievementsEarned[ach] = true
    end
    for ach, _ in pairs(achievementsEarned) do
        print('ach', ach)
        AddFontToCache(ach)
    end
end
