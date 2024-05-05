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
-- local currentPlayerRegistry = otherRegistry
-- local currentPlayerGrid = otherGrid

local difficultyLevel = 0

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
    for x, col in pairs(theRegistry) do
        for y, regChar in pairs(col) do
            if regChar == char then
                table.insert(foundCoords, { x = x, y = y })
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


local function printGrid(theGrid, width, height)
    -- Print the grid
    for col = 1, width do
        for row = 1, height do
            io.write(theGrid[col][row] .. " ")
        end
        io.write("\n")
    end
end

local function isCellNeighbor(playerPos, cellPos)
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

    local randomNum = math.random() * totalWeight
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
    -- for _, v in ipairs(findAllInRegistry(registry, ENEMY_CHARACTER)) do
    --     print('x', v.x, 'y', v.y)
    -- end
end

local function occupied(x, y)
    local entity = registry[x][y]
    if entity == MAIN_CHARACTER or entity == ENEMY_CHARACTER then
        return true
    end
end

local function moveMainCharacterInRegistry(registeredTo, width, height)
    for col = 1, width do
        for row = 1, height do
            -- delete old main char pos
            if registeredTo[col][row] == MAIN_CHARACTER and (POS.x ~= col or POS.y ~= row) then
                registeredTo[col][row] = getRandomElement(GROUND_CHARACTERS)
            end
            if POS.x == col and POS.y == row then
                registeredTo[col][row] = MAIN_CHARACTER
            end
        end
    end
end

function love.update()
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
end

function GenerateEnemies()
    local realDiff = difficultyLevel
    if difficultyLevel > gridHeight * gridWidth then
        realDiff = gridHeight * gridWidth
    end
    print('real difficulty ceiling', realDiff)
    for i = 1, 3 + realDiff do
        local placementCandidate = {}
        while true do
            placementCandidate.x = math.random(gridWidth)
            placementCandidate.y = math.random(gridHeight)
            if not isCellNeighbor(POS, placementCandidate) then
                registry[placementCandidate.x][placementCandidate.y] = ENEMY_CHARACTER
                break
            else
                print('hit character at ', POS.x, POS.y)
            end
        end
    end
end

function love.keyreleased(key)
    local xlimit, ylimit = getPlayerGridBounds()
    if key == "escape" then
        love.event.quit()
    end
    if key == "up" then
        if POS.y > 1 then
            if IsNotObstacle({ x = POS.x, y = POS.y - 1 }) then
                POS.y = POS.y - 1
            end
        end
    end
    if key == "down" then
        if POS.y < ylimit then
            if IsNotObstacle({ x = POS.x, y = POS.y + 1 }) then
                POS.y = POS.y + 1
            end
        end
    end
    if key == "left" then
        if POS.x > 1 then
            if IsNotObstacle({ x = POS.x - 1, y = POS.y }) then
                POS.x = POS.x - 1
            end
        end
    end
    if key == "right" then
        if POS.x < xlimit then
            if IsNotObstacle({ x = POS.x + 1, y = POS.y }) then
                POS.x = POS.x + 1
            end
        end
    end
    moveMainCharacterInRegistry(currentPlayerRegistry, xlimit, ylimit)
end

local function centerOfCell(theGrid, col, row)
    -- Calculate the center of the cell
    local x = (col + 0.5) * CELL_SIZE
    local y = (row + 0.25) * CELL_SIZE
    -- Get the width and height of the character
    local textWidth = love.graphics.getFont():getWidth(theGrid[col][row])
    -- local textHeight = love.graphics.getFont():getHeight()
    -- if FIXED_WIDTH_FONT then return x, y end
    -- Adjust the position of the character to center it in the cell
    local textX = x - (textWidth / 2)
    local textY = y -- - (textHeight / 2)
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

-- Draw the grid
function love.draw()
    -- RENDER THE MAIN GRID
    drawGrid(grid, gridWidth, gridHeight, { .1, .1, .1 }, { 0, 1, 0 })
    -- RENDER THE OTHER SIDE
    local otherGridStart = (gridWidth + 1)
    drawGrid(otherGrid, otherWidth, otherHeight, { .1, .1, .3 }, { 0, 1, 0 }, otherGridStart)
end

function IsNotObstacle(newPosition)
    if registry[newPosition.x][newPosition.y] == ENEMY_CHARACTER then
        return false
    end
    return true
end
