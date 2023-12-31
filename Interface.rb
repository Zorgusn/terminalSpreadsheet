require "curses"
require_relative "Parser.rb"
require_relative "Lexer.rb"
require_relative "Token.rb"
require_relative "Model.rb"
include Curses
include ParserModule
include Lexer
include Tokens
include Model

# Runtime loop
begin

    # ========================================================== CONSTANTS declaration | Start

    init_screen
    noecho
    crmode
    curs_set(2)

    # constants
    INSTRUCTIONS_PROMPT = "\'W/A/S/D\' to navigate | \'Enter\' to edit | \'Backspace\' to delete | \'Escape\' to exit program or cancel edit"
    LOCATION_PROMPT = "You are currently in Cell: "
    EDITOR_LINES = 3                                    # height of the EDITOR_WINDOW
    GRID_LINES = (lines - EDITOR_LINES) / 3 * 3 + 2     # height of the GRID_WINDOW
    ERROR_LINES = 4                                     # height of the error_window
    ERROR_COLS = 69                                     # width  of the error_window
    ERROR_TOP = 0                                       # starting line of error_window
    ERROR_BOTTOM = ERROR_TOP + ERROR_LINES              # ending   line of error_window; used for rendering calculations
    ERROR_LEFT = cols / 2 - 37                          # starting col  of error_window
    CELL_NUM_COLS = ((cols - 1) / 10)                   # number of cells in a row; used for rendering calculations
    CELL_NUM_ROWS = GRID_LINES / 3 - 1                  # number of cells in a col; used for rendering calculations
    CELL_HEIGHT = 3                                     # number of lines per cell; used for rendering calculations
    CELL_WIDTH = 10                                     # number of cols  per cell; used for rendering calculations
    CONTENTS_MAX_LEN = 6                # max normally displayed chars in a cell; used for rendering cell contents variably
    CELL_MAX_LEN = 9                    # max total displayed chars in a cell;    used for rendering cell contents variably
    MIN_LINE = 5            # minimum cell y value in the window; used for out-of-bounds checks when navigating the grid
    MIN_COL = 1             # minumum cell x value in the window; used for out-of-bounds checks when navigating the grid
    LOCATION_COL = 28       # col of the end of the LOCATION_PROMPT; used for updateing cur_address display

    # variables
    cur_line = 5        # starting line of the [0,0] cell
    cur_col = 1         # starting col of the [0,0] cell
    cur_char = -1       # invalid cur_char placeholder
    cur_address = [0,0] # x, y coords; inverted from how curses deals with it
    cur_contents = ""   # contents of [0,0] is empty at init
    UNEVALUATED_GRID = Grid.new     # unevaluated grid
    EVALUATED_GRID = Grid.new       # evaluated grid + enviornment is based on the evaluated declaration
    env = Environment.new(EVALUATED_GRID)
    parser = Parser.new # parser

    # Make grid parent window & the editor subwindow
    GRID_WINDOW = Window.new(lines, cols, 0, 0);
    EDITOR_WINDOW = GRID_WINDOW.subwin(EDITOR_LINES, cols, 0, 0)
    
    # Input Key Constants; fuck curses' constants
    BACKSPACE = 8
    ENTER = 10
    ESCAPE = 27

    # ========================================================== CONSTANTS declaration | End

    # ========================================================== GRID_WINDOW Render | Start

    for i in EDITOR_LINES + 1...GRID_LINES
        if i - 1 == EDITOR_LINES        # top row
            GRID_WINDOW.setpos(i, 0)
            GRID_WINDOW.addch('┌')
            GRID_WINDOW.addstr('─────────┬'*CELL_NUM_COLS)
            GRID_WINDOW.setpos(i, CELL_NUM_COLS*CELL_WIDTH)
            GRID_WINDOW.addch('┐')
            GRID_WINDOW.setpos(i - 1, 0)
            GRID_WINDOW.addstr(LOCATION_PROMPT)
            
        elsif i + 1 == GRID_LINES       # bottom row
            GRID_WINDOW.setpos(i, 0)
            GRID_WINDOW.addch('└')
            GRID_WINDOW.addstr('─────────┴'*CELL_NUM_COLS)
            GRID_WINDOW.setpos(i, CELL_NUM_COLS*CELL_WIDTH)
            GRID_WINDOW.addch('┘')
            GRID_WINDOW.setpos(i + 1, 0)
            GRID_WINDOW.addstr(INSTRUCTIONS_PROMPT)
            
        elsif (i-1) % 3 == 0            # all intermediate deliniator rows
            GRID_WINDOW.setpos(i, 0)
            GRID_WINDOW.addch('├')
            GRID_WINDOW.addstr('─────────┼'*CELL_NUM_COLS)
            GRID_WINDOW.setpos(i, CELL_NUM_COLS*CELL_WIDTH)
            GRID_WINDOW.addch('┤')

        else                            # all column-only rows
            GRID_WINDOW.setpos(i, 0)
            GRID_WINDOW.addch('│')
            GRID_WINDOW.addstr('         │'*CELL_NUM_COLS)
        end
    end
    GRID_WINDOW.refresh
    # ========================================================== GRID_WINDOW Render | End

    while cur_char != ESCAPE                                # Grid Window Loop
        
        # ======================================================= Match display with Grid contents | Start
        for cell_col in 0...CELL_NUM_COLS
            for cell_row in 0...CELL_NUM_ROWS
                render_line = 5 + (CELL_HEIGHT * cell_row)
                render_col = 1 + (CELL_WIDTH * cell_col)
                render_address = [0 + cell_col, 0 + cell_row]

                GRID_WINDOW.setpos(render_line, render_col)             # enter current cell
                GRID_WINDOW.addstr(' '*9)                               # clear cell contents before attempting to update
                GRID_WINDOW.refresh                                     # update grid window

                EDITOR_WINDOW.setpos(0, 0)                              # Enter editor window
                EDITOR_WINDOW.clear                                     # clear editor window before attempting to update
                EDITOR_WINDOW.refresh                                   # update editor window

                if UNEVALUATED_GRID.retrieve(copy_address(render_address)) != nil && EVALUATED_GRID.retrieve(copy_address(render_address)) != nil && EVALUATED_GRID.retrieve(copy_address(render_address)) != ""    # if there is cell contents
                    EDITOR_WINDOW.addstr(UNEVALUATED_GRID.retrieve(copy_address(render_address)))                        # display unevaulated cell contents in the editor window
                    EDITOR_WINDOW.refresh                                                   # update editor window

                    GRID_WINDOW.setpos(render_line, render_col)               # enter current cell

                    if EVALUATED_GRID.retrieve(copy_address(render_address)).is_a?(NewInteger) && EVALUATED_GRID.retrieve(copy_address(render_address)).value == 0

                            for i in 0...CELL_MAX_LEN                           # up to 9 chars displayed total
                                if UNEVALUATED_GRID.retrieve(copy_address(render_address))[i] != nil                         # if there is a char to print
                                    if (i < CONTENTS_MAX_LEN)                   # display first 6 chars normally
                                        GRID_WINDOW.addch(UNEVALUATED_GRID.retrieve(copy_address(render_address))[i])        # display evaluated cell contents in the cell
                                    else                                        # mask last 3 chars as '.' to show that
                                        GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                                    end
                                end
                            end

                    else
                        begin       # Attempt to display evaulated cell contents within cell
                            expression = EVALUATED_GRID.retrieve(copy_address(render_address)).evaluate(env).display

                            for i in 0...CELL_MAX_LEN                           # up to 9 chars displayed total
                                if expression[i] != nil                         # if there is a char to print
                                    if i < CONTENTS_MAX_LEN                     # display first 6 chars normally
                                        GRID_WINDOW.addch(expression[i])        # display evaluated cell contents in the cell
                                    else                                        # mask last 3 chars as '.' to show that
                                        GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                                    end
                                end
                            end

                        rescue TypeError, IndexError, UninitializedCellError => e   # catch the 3 possible errors
                            # =================================================== error_window Render | Start

                            error_window = Window.new(ERROR_LINES, ERROR_COLS, ERROR_TOP, ERROR_LEFT)
                            for i in ERROR_TOP...ERROR_BOTTOM
                                if i == ERROR_TOP               # top row
                                    error_window.setpos(i, 0)
                                    error_window.addch('╔')
                                    error_window.addstr('═'*(ERROR_COLS-2))
                                    error_window.addch('╗')

                                elsif i + 1 == ERROR_BOTTOM     # bottom row
                                    error_window.setpos(i, 0)
                                    error_window.addch('╚')
                                    error_window.addstr('═'*(ERROR_COLS-2))
                                    error_window.addch('╝')

                                else                            # intermediary rows
                                    error_window.setpos(i, 0)
                                    error_window.addch('║')
                                    error_window.addstr(' '*(ERROR_COLS-2))
                                    error_window.addch('║')

                                end
                            end
                            error_window.setpos(1, 1)   # display error message on the top line
                            error_window.addstr(e.message)
                            error_window.setpos(2, 20)  # display user prompt on the bottom line
                            error_window.addstr("Press Any Key to Continue... ")
                            error_window.refresh

                            # =================================================== error_window Render | End

                            error_window.getch
                            error_window.clear
                            error_window.refresh
                            UNEVALUATED_GRID.place(copy_address(render_address), nil)
                            EVALUATED_GRID.place(copy_address(render_address), nil)
                            error_window.close

                            GRID_WINDOW.setpos(render_line, render_col)                   # enter current cell
                            GRID_WINDOW.addstr(' '*9)                               # clear cell contents
                            GRID_WINDOW.refresh                                     # update grid window

                            EDITOR_WINDOW.setpos(0, 0)                              # Enter editor window
                            EDITOR_WINDOW.clear                                     # clear editor window
                            EDITOR_WINDOW.refresh                                   # update editor window

                        end
                        GRID_WINDOW.refresh

                    end
                end
            end
        end

        GRID_WINDOW.setpos(cur_line, cur_col)                   # enter current cell
        GRID_WINDOW.addstr(' '*9)                               # clear cell contents before attempting to update
        GRID_WINDOW.setpos(EDITOR_LINES, LOCATION_COL)          # go to the end of the location prompt
        GRID_WINDOW.addstr(' '*9)                               # clear previous cur_address display
        GRID_WINDOW.setpos(EDITOR_LINES, LOCATION_COL)          # go back to print the location
        GRID_WINDOW.addstr("#{cur_address}")                    # update cur_address display
        GRID_WINDOW.refresh                                     # update grid window

        EDITOR_WINDOW.setpos(0, 0)                              # Enter editor window
        EDITOR_WINDOW.clear                                     # clear editor window before attempting to update
        EDITOR_WINDOW.refresh                                   # update editor window

        if UNEVALUATED_GRID.retrieve(cur_address) != nil && EVALUATED_GRID.retrieve(cur_address) != nil && EVALUATED_GRID.retrieve(cur_address) != ""    # if there is cell contents
            EDITOR_WINDOW.addstr(UNEVALUATED_GRID.retrieve(cur_address))                        # display unevaulated cell contents in the editor window
            EDITOR_WINDOW.refresh                                                   # update editor window

            GRID_WINDOW.setpos(cur_line, cur_col)               # enter current cell

            if EVALUATED_GRID.retrieve(cur_address).is_a?(NewInteger) && EVALUATED_GRID.retrieve(cur_address).value == 0

                    for i in 0...CELL_MAX_LEN                           # up to 9 chars displayed total
                        if UNEVALUATED_GRID.retrieve(cur_address)[i] != nil                         # if there is a char to print
                            if (i < CONTENTS_MAX_LEN)                   # display first 6 chars normally
                                GRID_WINDOW.addch(UNEVALUATED_GRID.retrieve(cur_address)[i])        # display evaluated cell contents in the cell
                            else                                        # mask last 3 chars as '.' to show that
                                GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                            end
                        end
                    end

            else
                begin       # Attempt to display evaulated cell contents within cell
                    expression = EVALUATED_GRID.retrieve(cur_address).evaluate(env).display

                    for i in 0...CELL_MAX_LEN                           # up to 9 chars displayed total
                        if expression[i] != nil                         # if there is a char to print
                            if i < CONTENTS_MAX_LEN                     # display first 6 chars normally
                                GRID_WINDOW.addch(expression[i])        # display evaluated cell contents in the cell
                            else                                        # mask last 3 chars as '.' to show that
                                GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                            end
                        end
                    end

                rescue TypeError, IndexError, UninitializedCellError => e   # catch the 3 possible errors
                    # =================================================== error_window Render | Start

                    error_window = Window.new(ERROR_LINES, ERROR_COLS, ERROR_TOP, ERROR_LEFT)
                    for i in ERROR_TOP...ERROR_BOTTOM
                        if i == ERROR_TOP               # top row
                            error_window.setpos(i, 0)
                            error_window.addch('╔')
                            error_window.addstr('═'*(ERROR_COLS-2))
                            error_window.addch('╗')

                        elsif i + 1 == ERROR_BOTTOM     # bottom row
                            error_window.setpos(i, 0)
                            error_window.addch('╚')
                            error_window.addstr('═'*(ERROR_COLS-2))
                            error_window.addch('╝')

                        else                            # intermediary rows
                            error_window.setpos(i, 0)
                            error_window.addch('║')
                            error_window.addstr(' '*(ERROR_COLS-2))
                            error_window.addch('║')

                        end
                    end
                    error_window.setpos(1, 1)   # display error message on the top line
                    error_window.addstr(e.message)
                    error_window.setpos(2, 20)  # display user prompt on the bottom line
                    error_window.addstr("Press Any Key to Continue... ")
                    error_window.refresh

                    # =================================================== error_window Render | End

                    error_window.getch
                    error_window.clear
                    error_window.refresh
                    UNEVALUATED_GRID.place(cur_address, nil)
                    EVALUATED_GRID.place(cur_address, nil)
                    error_window.close

                    GRID_WINDOW.setpos(cur_line, cur_col)                   # enter current cell
                    GRID_WINDOW.addstr(' '*9)                               # clear cell contents
                    GRID_WINDOW.refresh                                     # update grid window

                    EDITOR_WINDOW.setpos(0, 0)                              # Enter editor window
                    EDITOR_WINDOW.clear                                     # clear editor window
                    EDITOR_WINDOW.refresh                                   # update editor window

                end
                GRID_WINDOW.refresh

            end
        end

        # ======================================================= Match display with Grid contents | End

        GRID_WINDOW.setpos(cur_line, cur_col)               # set cursor position
        cur_char = GRID_WINDOW.getch                        # wait for input

        # =================================================== Edit Cell Contents | Start
        
        if cur_char == ENTER
            flash                                           # flash for visual change indication
            GRID_WINDOW.setpos(cur_line + 1, cur_col + 8)   # set cursor to the bottom right of the cell
            GRID_WINDOW.addch('■')                          # put marker to indicate current cell
            GRID_WINDOW.setpos(cur_line, cur_col)           # set cursor to top left of the cell
            GRID_WINDOW.refresh
            EDITOR_WINDOW.setpos(0, 0)                      # set cursor into the editor window
            EDITOR_WINDOW.clear                             # clear editor window
            EDITOR_WINDOW.refresh

            cur_char = -1                                   # set cur_char so that its able to enter the editor loop
            if EVALUATED_GRID.retrieve(copy_address(cur_address)) != nil            # update cur_contents to match current cell
                cur_contents = UNEVALUATED_GRID.retrieve(copy_address(cur_address))
                EDITOR_WINDOW.addstr(UNEVALUATED_GRID.retrieve(copy_address(cur_address)))
            else
                cur_contents = ''
            end

            while cur_char != ESCAPE && cur_char != ENTER   # Editor Window Loop
                cur_char = EDITOR_WINDOW.getch
                if cur_char == BACKSPACE && cur_contents.length != 0    # Branch for Backspace
                    cur_contents[-1] = ""               # remove the last character
                    GRID_WINDOW.setpos(cur_line, cur_col)                   # enter current cell
                    GRID_WINDOW.addstr(' '*9)                               # clear cell contents before attempting to update
                    GRID_WINDOW.setpos(cur_line, cur_col)                   # reset position within cell
                    for i in 0...CELL_MAX_LEN                           # up to 9 chars displayed total
                        if cur_contents[i] != nil                         # if there is a char to print
                            if (i < CONTENTS_MAX_LEN)                   # display first 6 chars normally
                                GRID_WINDOW.addch(cur_contents[i])        # display evaluated cell contents in the cell
                            else                                        # mask last 3 chars as '.' to show that
                                GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                            end
                        end
                    end
                    GRID_WINDOW.refresh                                     # update grid window
                    EDITOR_WINDOW.setpos(0,0)
                    EDITOR_WINDOW.clear                 # clear the contents
                    EDITOR_WINDOW.addstr(cur_contents)  # rewrite the contents

                elsif cur_char == ENTER                                 # Branch for Enter
                    flash                                   # flash for visual indication
                    UNEVALUATED_GRID.place(copy_address(cur_address), cur_contents)       # update grid hashmap

                    if cur_contents != "" && cur_contents[0] == "="
                        begin
                            EVALUATED_GRID.place(copy_address(cur_address), parser.parse(lex(cur_contents[1..-1])))
                        rescue TypeError, IndexError, UninitializedCellError => e   # catch the 3 possible errors
                            # =================================================== error_window Render | Start
        
                            error_window = Window.new(ERROR_LINES, ERROR_COLS, ERROR_TOP, ERROR_LEFT)
                            for i in ERROR_TOP...ERROR_BOTTOM
                                if i == ERROR_TOP               # top row
                                    error_window.setpos(i, 0)
                                    error_window.addch('╔')
                                    error_window.addstr('═'*(ERROR_COLS-2))
                                    error_window.addch('╗')
        
                                elsif i + 1 == ERROR_BOTTOM     # bottom row
                                    error_window.setpos(i, 0)
                                    error_window.addch('╚')
                                    error_window.addstr('═'*(ERROR_COLS-2))
                                    error_window.addch('╝')
        
                                else                            # intermediary rows
                                    error_window.setpos(i, 0)
                                    error_window.addch('║')
                                    error_window.addstr(' '*(ERROR_COLS-2))
                                    error_window.addch('║')
        
                                end
                            end
                            error_window.setpos(1, 1)   # display error message on the top line
                            error_window.addstr(e.message)
                            error_window.setpos(2, 20)  # display user prompt on the bottom line
                            error_window.addstr("Press Any Key to Continue... ")
                            error_window.refresh
        
                            # =================================================== error_window Render | End
        
                            error_window.getch
                            error_window.clear
                            error_window.refresh
                            UNEVALUATED_GRID.place(copy_address(cur_address), nil)
                            EVALUATED_GRID.place(copy_address(cur_address), nil)
                            error_window.close

                            GRID_WINDOW.setpos(cur_line, cur_col)                   # enter current cell
                            GRID_WINDOW.addstr(' '*9)                               # clear cell contents
                            GRID_WINDOW.refresh                                     # update grid window

                            EDITOR_WINDOW.setpos(0, 0)                              # Enter editor window
                            EDITOR_WINDOW.clear                                     # clear editor window
                            EDITOR_WINDOW.refresh                                   # update editor window
        
                        end
                    else
                        EVALUATED_GRID.place(copy_address(cur_address), NewInteger.new(0))
                    end
                    GRID_WINDOW.setpos(cur_line + 1, cur_col)               # set cursor to the bottom right of the cell
                    GRID_WINDOW.addstr(' '*9)                               # clear cell editing marker
                    cur_contents = ''                       # clear out the cur_contents buffer
                    # Editor loop will then exit
                
                elsif cur_char != ESCAPE && !cur_char.is_a?(Integer)    # Branch for User Input
                    cur_contents += cur_char        # append cur_char to the end of cur_contents
                    GRID_WINDOW.setpos(cur_line, cur_col + cur_contents.length - 1)
                    if  cur_contents.length - 1 < CONTENTS_MAX_LEN                    # display first 6 chars normally
                        GRID_WINDOW.addch(cur_contents[cur_contents.length - 1])      # display evaluated cell contents in the cell
                    elsif cur_contents.length - 1 < CELL_MAX_LEN                      # mask last 3 chars as '.' to show that
                        GRID_WINDOW.addch('.')                  #   not all contents are being displayed
                    end
                    GRID_WINDOW.refresh
                    EDITOR_WINDOW.setpos(0, cur_contents.length - 1)
                    EDITOR_WINDOW.addch(cur_char)   # show the user that they typed a char
                    EDITOR_WINDOW.refresh

                end
            end

            if (cur_char == ESCAPE)
                cur_char = -1
            end

            GRID_WINDOW.setpos(cur_line, cur_col)           # set cursor to top left of the cell

        elsif cur_char == BACKSPACE

            UNEVALUATED_GRID.place(copy_address(cur_address), nil)
            EVALUATED_GRID.place(copy_address(cur_address), nil)

        # =================================================== Edit Cell Contents | End

        # =================================================== Navigate Cells (with wasd) | Start

        elsif cur_char == 'w'
            GRID_WINDOW.setpos(cur_line + 1, cur_col + 8)       # set to bottom right of the cell
            GRID_WINDOW.addch(' ')                              # clear marker to indicate current cell

            if cur_line - CELL_HEIGHT >= MIN_LINE               # if nav up is inbounds
                cur_line -= CELL_HEIGHT                         # update cur_line
                cur_address[1] -= 1                             # update cur_address y (lines) value
            end
            GRID_WINDOW.setpos(cur_line, cur_col)               # set cursor to top left of the (possibly) NEW cell

        elsif cur_char == 's'
            GRID_WINDOW.setpos(cur_line + 1, cur_col + 8)       # set to bottom right of the cell
            GRID_WINDOW.addch(' ')                              # clear marker to indicate current cell

            if cur_line + CELL_HEIGHT <= lines - CELL_HEIGHT - 1# if nav down is inbounds
                cur_line += CELL_HEIGHT                         # update cur_line
                cur_address[1] += 1                             # update cur_address y (lines) value
            end
            GRID_WINDOW.setpos(cur_line, cur_col)               # set cursor to top left of the (possibly) NEW cell

        elsif cur_char == 'a'
            GRID_WINDOW.setpos(cur_line + 1, cur_col + 8)       # set to bottom right of the cell
            GRID_WINDOW.addch(' ')                              # clear marker to indicate current cell

            if cur_col - CELL_WIDTH >= MIN_COL                  # if nav left is inbounds
                cur_col -= CELL_WIDTH                           # update cur_col
                cur_address[0] -= 1                             # update cur_address x (cols) value
            end
            GRID_WINDOW.setpos(cur_line, cur_col)               # set cursor to top left of the (possibly) NEW cell

        elsif cur_char == 'd'
            GRID_WINDOW.setpos(cur_line + 1, cur_col + 8)       # set to bottom right of the cell
            GRID_WINDOW.addch(' ')                              # clear marker to indicate current cell

            if cur_col + CELL_WIDTH <= cols - CELL_WIDTH        # if nav right is inbounds
                cur_col += CELL_WIDTH                           # update cur_col
                cur_address[0] += 1                             # update cur_address x (cols) value
            end
            GRID_WINDOW.setpos(cur_line, cur_col)               # set cursor to top left of the (possibly) NEW cell
            
        # =================================================== Navigate Cells (with wasd) | End
        end
    end

ensure
    close_screen
end