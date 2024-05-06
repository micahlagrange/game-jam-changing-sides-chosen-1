local Luafinding = require("libs.luafinding")
local Vector = require("libs.vector")
local Explosions = require("src.explosion")
local Shake = require('src.shake')
local debug = require('src.debug')

math.randomseed(os.time())
love.graphics.setDefaultFilter('nearest', 'nearest')

MAIN_CHARACTER = '@'
ENEMY_CHARACTER = '0'
CHOSEN_1_CHARACTER = '1'
GROUND_CHARACTERS = { '.', ',', "'" } --, '·' , CEDILLA, DEGREES, INTERPUNCT, ACCENT, BACKTICK, ORDINAL }
MAX_HP = 3
SAVE_SCORE_FILE = "highscore.c1d"

COLOR_GUI_TEXT = { 0, 1, 0.976 }
COLOR_GROUND = { 0.165, .5, 0.29 }
COLOR_ENEMY_CHARACTERS = { 1, 1, 1 }
COLOR_ENEMY_EXPLOSION = { 0.929, 0.408, 0.102 }
COLOR_MAIN_CHAR_EXPLOSION = { 0.624, 0.929, 0.102 }
COLOR_CHOSEN_1 = { 0.91, 0.855, 0.584 }
COLOR_BG_MAIN = { .1, .1, .1 }
COLOR_BG_OTHERSIDE = { .1, .1, .3 }
COLOR_MAIN_CHAR = { 0, 1, 0 }
COLOR_MENU_TEXT = { .8, .2, .3 }

local grid = {}
local gridWidth = 7
local gridHeight = 5
local registry = {}
local otherGrid = {}
local otherWidth = 5
local otherHeight = 5
local otherRegistry = {}
local currentPlayerRegistry = registry
local currentPlayerGrid = grid
local currentPlayerColor = { COLOR_MAIN_CHAR }
local difficultyLevel = 1
local playerHp = 0
local gameResettable = false
local claimedChosen1 = false
local points = 0
local chosen1Location = {}
local playable = false
local highScoreDefeated = false
local previousHighScore = 0

HURT_DELAY = .3
local hurtTimer = 0

love.window.setMode(WINDOW_WIDTH * SCALE, WINDOW_HEIGHT * SCALE)

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
    local textWidth = love.graphics.getFont():getWidth(theGrid[1][1])
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

function love.keyreleased(key)
    if key == "escape" then
        love.event.quit()
    end
    if not playable then
        if key == "return" then playable = true end
        return
    end
    if gameResettable then
        if key == "f1" then
            ResetGame()
        end
        return
    elseif claimedChosen1 then
        if key == "return" then
            claimedChosen1 = false
            TeleportTo(registry, grid, otherRegistry, { x = 1, y = 1 })
            PlaceMainCharacter()
            MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, POS)
            PlaceChosen1()
            GenerateEnemies()
            playerHp = MAX_HP + math.floor(difficultyLevel / 3)
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
        Explosions.new(POS.x, POS.y, 10, { 0, 1, .3 })
        local neighbors = findAllInNeighbors(ENEMY_CHARACTER)
        if #neighbors >= 1 then
            kill(neighbors, registry, true)
        end
    end
    local xlimit, ylimit = getPlayerGridBounds()
    local oldPos = { x = POS.x, y = POS.y }
    if vector.x and vector.y then
        if currentPlayerRegistry == otherRegistry and IsTheChosen1(vector) then
            difficultyLevel = difficultyLevel + 1
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
    currentPlayerRegistry = registry
    currentPlayerGrid = grid
    LoadHighScore()
    playerHp = MAX_HP
    love.graphics.setFont(love.graphics.newFont('fonts/white-rabbit.TTF', FONT_SIZE * SCALE))
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
    local saveData, _ = love.filesystem.read(SAVE_SCORE_FILE)
    if saveData then previousHighScore = saveData end
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
        '      LEVEL:' .. difficultyLevel ..
        '     POINTS:' .. points,
        0,
        10)
    love.graphics.print('[SPACEBAR/LCTRL]: shoot adjacent cells\n' ..
        '[ARROWKEYS]: move cardinally\n' ..
        '  - Objective: Find the chosen 1',
        0,
        6 * CELL_SIZE + 10)
    if not playable then
        local introText = "[ENTER]: Start a New Game\n\n" ..
            "High Score: " .. previousHighScore

        DrawMenu(introText)
    end
    if gameResettable then
        local congrats = "No congrats are in order"
            .. "\nTry to beat high score!"
            .. "\nPrevious High Score:" .. previousHighScore
        if highScoreDefeated then
            congrats = "NEW HIGH SCORE!! --> " .. points
        end
        DrawMenu("[F1]: Reset Game\n"
            .. "[ESCAPE]:   Exit\n"
            .. congrats,
            highScoreDefeated and COLOR_CHOSEN_1 or COLOR_MENU_TEXT)
    end
    if claimedChosen1 then
        DrawMenu("CHOSEN 1 FOUND!!\n\n"
            .. "[ENTER]: Progress To Level " .. difficultyLevel)
    end
end

function MoveEnemies()
    local enemies = findAllInRegistry(registry, ENEMY_CHARACTER)
    for _, enemyPos in ipairs(enemies) do
        local oldPos = {}
        oldPos.x = enemyPos.x
        oldPos.y = enemyPos.y
        local path = Luafinding(toVector(enemyPos), toVector(POS), grid):GetPath()
        if path and path[2] then
            local stepTo = path[2]
            if equalCoords(stepTo, POS) then
                HurtMainCharacter()
            else
                if IsNotObstacle(stepTo, gridWidth, gridHeight) then
                    enemyPos = stepTo
                    MoveCharacterInRegistry(registry, ENEMY_CHARACTER, oldPos, enemyPos)
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
    local realDiff = difficultyLevel
    local minemies = 1
    local maxemies = (gridHeight * gridWidth) - 10
    if difficultyLevel > maxemies then
        realDiff = maxemies
    end
    print('generating ', minemies + realDiff, 'enemies')
    for _ = 1, minemies + realDiff do
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

function DrawMenu(text, textColor)
    if not textColor then textColor = COLOR_MENU_TEXT end
    love.graphics.setColor({ .1, .3, .3 })
    love.graphics.rectangle('fill',
        1.5 * CELL_SIZE - (.5 * CELL_SIZE),
        1.5 * CELL_SIZE - (.5 * CELL_SIZE),
        WINDOW_WIDTH * SCALE - (2 * CELL_SIZE),
        WINDOW_HEIGHT * SCALE - (4 * CELL_SIZE)
    )
    love.graphics.setColor({ .1, .2, .3 })
    love.graphics.rectangle('fill',
        2 * CELL_SIZE - (.5 * CELL_SIZE),
        2 * CELL_SIZE - (.5 * CELL_SIZE),
        WINDOW_WIDTH * SCALE - (3 * CELL_SIZE),
        WINDOW_HEIGHT * SCALE - (5 * CELL_SIZE)
    )
    love.graphics.setColor(textColor)
    love.graphics.print(text,
        3 * CELL_SIZE - (.5 * CELL_SIZE),
        (WINDOW_HEIGHT / 3.54) * SCALE)
end

function GameOver()
    local data, _ = love.filesystem.read(SAVE_SCORE_FILE)
    if not data then
        love.filesystem.write(SAVE_SCORE_FILE, points)
        highScoreDefeated = true
    else
        if points > tonumber(data) then
            love.filesystem.write(SAVE_SCORE_FILE, points)
            highScoreDefeated = true
        end
    end
    LoadHighScore() -- do this so the var has it cached for other loops
    gameResettable = true
end

function ResetGame()
    points = 0
    highScoreDefeated = false
    gameResettable = false
    playable = true
    claimedChosen1 = false
    difficultyLevel = 1
    kill(findAllInRegistry(registry, ENEMY_CHARACTER), registry, false)
    TeleportTo(registry, grid, otherRegistry, { x = 1, y = 1 })
    love.load()
    MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, { x = 1, y = 1 }, POS)
end

function DrawMainCharacter()
    drawCharacter(MAIN_CHARACTER, currentPlayerGrid, POS, currentPlayerColor)
end

function DrawChosen1()
    drawCharacter(CHOSEN_1_CHARACTER, otherGrid, chosen1Location, COLOR_CHOSEN_1)
end

function DrawEnemies()
    for _, enemy in pairs(findAllInRegistry(registry, ENEMY_CHARACTER)) do
        drawCharacter(ENEMY_CHARACTER, grid, enemy, COLOR_ENEMY_CHARACTERS)
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
