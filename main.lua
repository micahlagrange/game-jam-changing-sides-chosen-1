local Luafinding = require("libs.luafinding")
local Vector = require("libs.vector")
local Explosions = require("src.explosion")
local Shake = require('src.shake')
local debug = require('src.debug')
require('src.chars')

math.randomseed(os.time())
love.graphics.setDefaultFilter('nearest', 'nearest')
love.window.setMode(WINDOW_WIDTH * SCALE, WINDOW_HEIGHT * SCALE)

CHOSEN_1_CHARACTER = '1'
GROUND_CHARACTERS = { '.', ',', "'", } --'·' } --, CHARS.CEDILLA } --, CHARS.DEGREES, CHARS.INTERPUNCT, CHARS.ACCENT, CHARS.BACKTICK, CHARS.ORDINAL }
ENEMY_CHARACTER = '0'
MAIN_CHARACTER = '@'

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
COLOR_SUBTLE_HINT = { .1, .5, .5 }
COLOR_WARNING_TEXT = { 1, .2, .4 }

SAVE_SCORE_FILE = ".highscore.c1d"
HURT_DELAY = .3
INPUT_DELAY = 1
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
local claimedChosen1 = false
local chosen1Location = {}
local currentPlayerRegistry = registry
local currentPlayerGrid = grid
local currentPlayerColor = { COLOR_MAIN_CHAR }
local difficultySetting = 3
local fontCache = {}
local fontCurrent = 1
local gameLevel = 1
local gameResettable = false
local highScoreDefeated = false
local hurtTimer = 0
local inputtable = true
local inputTimer = 0
local playerHp = difficultySetting
local playable = false
local points = 0
local previousHighScore = {}

previousHighScore[1] = 0
previousHighScore[2] = 0
previousHighScore[3] = 0
previousHighScore[4] = 0

local function getSaveFileName()
    return 'difficulty' .. difficultySetting .. SAVE_SCORE_FILE
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
        end
    end
end

local function kill(array, theRegistry, enemyKill)
    if theRegistry == nil then theRegistry = registry end
    if array == nil then return end
    -- aka kill
    for _, enemy in ipairs(array) do
        -- literally smash them into the GROUND lol
        theRegistry[enemy.x][enemy.y] = getRandomElement(GROUND_CHARACTERS)
        if enemyKill then
            points = points + 1
            Shake.startShake(.1, 1)
            Explosions.new(enemy.x, enemy.y, 20, { 1, 0, 0 })
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
    registeredTo[newPos.x][newPos.y] = character
end

function love.keyreleased(key)
    if key == "f" then CycleFont() end
    if key == "escape" and love.system.getOS() ~= WEB_OS then
        love.event.quit()
    end
    if not playable then
        if key == "left" or key == "down" then cycleDifficulty() end
        if key == "right" or key == "up" then cycleDifficulty(-1) end
        if key == "return" and inputtable then playable = true end
        return
    end
    if gameResettable then
        if key == "f1" then
            ResetGame()
        end
        return
    elseif claimedChosen1 then
        if key == "return" and inputtable then
            claimedChosen1 = false
            TeleportTo(registry, grid, otherRegistry, { x = 1, y = 1 })
            PlaceMainCharacter()
            MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, POS)
            PlaceChosen1()
            GenerateEnemies()
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
    if key == "up" or key == "w" then
        vector.x = POS.x
        vector.y = POS.y - 1
    elseif key == "down" or key == "s" then
        vector.x = POS.x
        vector.y = POS.y + 1
    elseif key == "left" or key == "a" then
        vector.x = POS.x - 1
        vector.y = POS.y
    elseif key == "right" or key == "d" then
        vector.x = POS.x + 1
        vector.y = POS.y
    elseif key == "space" or key == "lctrl" or key == "rctrl" then
        if currentPlayerRegistry == registry then
            Explosions.new(POS.x, POS.y, 10, { 0, 1, .3 })
            local neighbors = findAllInNeighbors(ENEMY_CHARACTER)
            if #neighbors >= 1 then
                kill(neighbors, registry, true)
            end
        end
    end
    local xlimit, ylimit = getPlayerGridBounds()
    local oldPos = { x = POS.x, y = POS.y }
    if vector.x and vector.y then
        if currentPlayerRegistry == otherRegistry and IsTheChosen1(vector) then
            gameLevel = gameLevel + 1
            if gameLevel % 5 == 4 then
                inputTimer = INPUT_DELAY
            end
            if gameLevel % 5 == 0 then
                inputTimer = INPUT_DELAY
                diagonalable = true
            else
                diagonalable = false
            end
            claimedChosen1 = true
            points = points + 1
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

function love.load()
    CacheFonts()
    currentPlayerRegistry = registry
    currentPlayerGrid = grid
    LoadHighScore()
    playerHp = difficultySetting
    love.graphics.setFont(fontCache[fontCurrent])
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
end

function PlaceChosen1()
    otherRegistry[chosen1Location.x][chosen1Location.y] = CHOSEN_1_CHARACTER
end

function PlaceMainCharacter()
    POS = { x = math.ceil(gridWidth / 2), y = math.ceil(gridHeight / 2) }
end

function love.update(dt)
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
        local saveData, _ = love.filesystem.read(getSaveFileName())
        if saveData then previousHighScore[difficultySetting] = saveData else previousHighScore[difficultySetting] = 0 end
    else
        if points > previousHighScore[difficultySetting] then
            previousHighScore[difficultySetting] = points
            highScoreDefeated = true
        end
    end
end

function GetDifficulty()
    return DIFFICULTY[difficultySetting]
end

-- Draw the grid
function love.draw()
    Shake.draw()
    -- RENDER THE MAIN GRID
    drawGrid(grid, gridWidth, gridHeight, COLOR_BG_MAIN, COLOR_GROUND)
    -- RENDER THE OTHER SIDE
    local otherGridStart = (gridWidth + 1)
    drawGrid(otherGrid, otherWidth, otherHeight, COLOR_BG_OTHERSIDE, COLOR_GROUND, otherGridStart)
    Explosions.draw()
    love.graphics.setColor(.1, .1, .8)
    love.graphics.print(
        '    CHARGE:' .. playerHp ..
        '      LEVEL:' .. gameLevel ..
        '     POINTS:' .. points,
        0,
        10)
    if playable and not gameResettable and not claimedChosen1 then
        love.graphics.print('[SPACE/CTRL]: attack\n' ..
            '[WASD]: move cardinally\n' ..
            ' Objective: Find the chosen 1',
            0,
            6 * CELL_SIZE + 10)
    end
    if not playable then
        local introText = "[ENTER]: Start a New Game\n"
            .. "[ARROWKEYS]: Difficulty\n"
            .. "             { " .. GetDifficulty() .. " }\n\n"
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
            congrats = "\n                NEW HIGH SCORE!!\n"
                .. "Difficulty " .. GetDifficulty() .. "--> " .. points
        end
        if love.system.getOS() ~= WEB_OS then
            escapeClause = "[ESCAPE]:   Exit\n"
        end
        DrawMenu("[F1]: reset\n"
            .. escapeClause
            .. congrats,
            highScoreDefeated and COLOR_CHOSEN_1 or COLOR_MENU_TEXT)
    end

    if claimedChosen1 then
        local goNextLevelText = ""
        local warningText = nil
        if gameLevel % 5 == 4 then warningText = "Elite swarms are\non their way" end
        if diagonalable then warningText = "An upgraded drone swarm...\nTHEY ATTACK DIAGONALLY" end
        if inputtable then goNextLevelText = "[ENTER]: Go To Level " .. gameLevel end
        DrawMenu("CHOSEN 1 FOUND!!\n\n"
            .. goNextLevelText,
            nil,
            warningText)
    end
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
                if IsNotObstacle(stepTo, gridWidth, gridHeight) then
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
    if inputTimer >= 0 then
        inputTimer = inputTimer - dt
        inputtable = false
    else
        inputtable = true
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

function GenerateEnemies()
    local numEnemies = gameLevel
    local minEnemies = 1
    local maxEnemies = (gridHeight * gridWidth)
    if gameLevel < minEnemies then numEnemies = minEnemies end
    if diagonalable then
        numEnemies = numEnemies / 2
    end
    if numEnemies > maxEnemies then
        print('reached maximum number of enemies')
        numEnemies = maxEnemies
    end
    print('generating ', minEnemies + numEnemies, 'enemies')
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
    local borderColor = COLOR_MENU_BOX_BORDER_NORMAL
    if GetDifficulty() == DIFFICULTY.Easy then
        borderColor = COLOR_MENU_BOX_BORDER_EASY
    elseif GetDifficulty() == DIFFICULTY.HARD then
        borderColor = COLOR_MENU_BOX_BORDER_HARD
    elseif GetDifficulty() == DIFFICULTY.EXTREME then
        borderColor = COLOR_MENU_BOX_BORDER_EXTREME
    end

    if textColor == nil then textColor = COLOR_MENU_TEXT end
    love.graphics.setColor(borderColor)
    love.graphics.rectangle('fill',
        1.5 * CELL_SIZE - (.5 * CELL_SIZE),
        1.5 * CELL_SIZE - (.5 * CELL_SIZE),
        WINDOW_WIDTH * SCALE - (2 * CELL_SIZE),
        WINDOW_HEIGHT * SCALE - (2 * CELL_SIZE)
    )
    love.graphics.setColor(COLOR_MENU_BOX)
    love.graphics.rectangle('fill',
        2 * CELL_SIZE - (.5 * CELL_SIZE),
        2 * CELL_SIZE - (.5 * CELL_SIZE),
        WINDOW_WIDTH * SCALE - (3 * CELL_SIZE),
        WINDOW_HEIGHT * SCALE - (3 * CELL_SIZE)
    )
    love.graphics.setColor(textColor)
    love.graphics.print(text,
        2.5 * CELL_SIZE - (.5 * CELL_SIZE),
        (WINDOW_HEIGHT / 3.54) * SCALE)

    if warningText then
        love.graphics.setColor(COLOR_WARNING_TEXT)
        love.graphics.print(warningText,
            2 * CELL_SIZE,
            WINDOW_HEIGHT * SCALE - 4 * CELL_SIZE)
    else
        local fontHint = "[F]: cycle fonts"
        love.graphics.setColor(COLOR_SUBTLE_HINT)
        love.graphics.print(fontHint,
            2 * CELL_SIZE,
            WINDOW_HEIGHT * SCALE - 2.5 * CELL_SIZE)
    end
end

function GameOver()
    local data = nil
    if love.system.getOS() ~= WEB_OS then
        data, _ = love.filesystem.read(getSaveFileName())
        if not data then
            love.filesystem.write(getSaveFileName(), points)
            highScoreDefeated = true
        else
            if points > tonumber(data) then
                love.filesystem.write(getSaveFileName(), points)
                highScoreDefeated = true
            end
        end
        LoadHighScore() -- do this so the var has it cached for other loops
    else
        if points > previousHighScore[difficultySetting] then
            previousHighScore[difficultySetting] = points
            highScoreDefeated = true
        end
    end
    gameResettable = true
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
    if otherRegistry[vector.x] and otherRegistry[vector.x][vector.y] then
        local discoveredThing = otherRegistry[vector.x][vector.y]
        if discoveredThing == CHOSEN_1_CHARACTER then
            return true
        end
    end
    return false
end

function CycleFont()
    fontCurrent = fontCurrent + 1
    if fontCurrent > #fontCache then fontCurrent = 1 end
    love.graphics.setFont(fontCache[fontCurrent])
end

function CacheFonts()
    local dir = "fonts/"
    local files = love.filesystem.getDirectoryItems(dir)
    for _, file in ipairs(files) do
        print(file)
        table.insert(fontCache, love.graphics.newFont(dir .. file, FONT_SIZE * SCALE))
    end
end
