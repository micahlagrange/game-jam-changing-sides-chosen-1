DEFAULT_FONT = 'fonts/white-rabbit.TTF'
DEBUG = true
SCALE = 5
WINDOW_WIDTH = 128
WINDOW_HEIGHT = 68
CELL_SIZE = 8 * SCALE -- Define the size of each cell in the grid
FIXED_WIDTH_FONT = true
FONT_SIZE = 5

function love.conf(t)
    t.title = "ChangingSidesChosen1"
    t.version = "11.4" -- It's a lie, we actually use 11.5 but itch.io throws a dumb error!
    t.console = true
    t.window.width = WINDOW_WIDTH
    t.window.height = WINDOW_HEIGHT
    t.window.vsync = 0
end
