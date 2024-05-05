local Luafinding = require("libs.luafinding")
local Vector = require("libs.vector")
local Explosions = require("src.fight")

math.randomseed(os.time())
love.graphics.setDefaultFilter('nearest', 'nearest')

local grid = {}
local gridWidth = 7
local gridHeight = 5
local registry = {}

local otherGrid = {}
local otherWidth = 5
local otherHeight = 5
local otherRegistry = {}

MAIN_CHARACTER = '@'
ENEMY_CHARACTER = '0'
CHOSEN_1_CHARACTER = '1'
GROUND_CHARACTERS = { '.', ',', "'" }

local currentPlayerRegistry = registry
local currentPlayerGrid = grid

local difficultyLevel = 1

love.window.setMode(WINDOW_WIDTH * SCALE, WINDOW_HEIGHT * SCALE)

local function fillFromRegistry(theGrid, width, height, theRegistry)
    for col = 1, width do
        theGrid[col] = {}
        for row = 1, height do
            theGrid[col][row] = theRegistry[col][row]
        end
    end
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
    local totalWeight = 0
    for i = 1, #array do
        totalWeight = totalWeight + (#array + 1 - i)
    end
    local randomNum = love.math.random() * totalWeight
    local weightSum = 0
    for i = 1, #array do
        weightSum = weightSum + (#array + 1 - i)
        if weightSum >= randomNum then
            return array[i]
        end
    end
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
    -- Calculate the center of the cell
    local x = (col + 0.5) * CELL_SIZE
    local y = (row + 0.25) * CELL_SIZE
    -- Get the width and height of the character
    local textWidth = love.graphics.getFont():getWidth(theGrid[col][row])
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
            -- character
            love.graphics.setColor(textColor)
            local textX, textY = centerOfCell(theGrid, col, row)
            love.graphics.print(theGrid[col][row], textX + (start * CELL_SIZE), textY)
        end
    end
end

function love.keyreleased(key)
    local xlimit, ylimit = getPlayerGridBounds()
    if key == "escape" then
        love.event.quit()
    end
    local vector = {}
    local oldPos = { x = POS.x, y = POS.y }
    if key == "up" then
        vector.x = POS.x
        vector.y = POS.y - 1
    elseif key == "down" then
        vector.x = POS.x
        vector.y = POS.y + 1
    elseif key == "left" then
        vector.x = POS.x - 1
        vector.y = POS.y
    elseif key == "right" then
        vector.x = POS.x + 1
        vector.y = POS.y
    elseif key == "lctrl" then
        Explosions.new(POS.x, POS.y, 30)
    end
    if vector.x and vector.y then
        if IsNotObstacle(vector, xlimit, ylimit) then
            POS.x = vector.x
            POS.y = vector.y
            MoveCharacterInRegistry(currentPlayerRegistry, MAIN_CHARACTER, oldPos, POS)
        end
    end

    MoveEnemies()
end

function love.load()
    love.graphics.setFont(love.graphics.newFont('fonts/white-rabbit.TTF', FONT_SIZE * SCALE))
    initRegistry(registry, gridWidth, gridHeight)
    initRegistry(otherRegistry, otherWidth, otherHeight)
    -- put the main character in the middle of the grid
    POS = { x = math.ceil(gridWidth / 2), y = math.ceil(gridHeight / 2) }
    currentPlayerRegistry[POS.x][POS.y] = MAIN_CHARACTER
    otherRegistry[math.floor(otherWidth / 2) + 1][math.floor(otherHeight / 2) + 1] = CHOSEN_1_CHARACTER
    -- pre-fill the grid from registry
    fillFromRegistry(grid, gridWidth, gridHeight, registry)
    -- pre-fill the otherSideGrid from registry
    fillFromRegistry(otherGrid, otherWidth, otherHeight, otherRegistry)
    GenerateEnemies()
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
end

-- Draw the grid
function love.draw()
    -- RENDER THE MAIN GRID
    drawGrid(grid, gridWidth, gridHeight, { .1, .1, .1 }, { 0, 1, 0 })
    -- RENDER THE OTHER SIDE
    local otherGridStart = (gridWidth + 1)
    drawGrid(otherGrid, otherWidth, otherHeight, { .1, .1, .3 }, { 0, 1, 0 }, otherGridStart)
    Explosions.draw()
end

function MoveEnemies()
    local enemies = findAllInRegistry(registry, ENEMY_CHARACTER)
    for _, enemyPos in ipairs(enemies) do
        local oldPos = {}
        oldPos.x = enemyPos.x
        oldPos.y = enemyPos.y
        local path = Luafinding(toVector(enemyPos), toVector(POS), grid):GetPath()
        if path and path[2] then
            enemyPos = path[2]
            MoveCharacterInRegistry(registry, ENEMY_CHARACTER, oldPos, enemyPos)
        end
    end
end

function GenerateEnemies()
    local realDiff = difficultyLevel
    local minemies = 3
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
