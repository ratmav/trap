-- trap/init.lua
-- A lightweight Neovim plugin for quick note-taking with auto-clearing.

-- Dependencies
local has_plenary, popup = pcall(require, "plenary.popup")
if not has_plenary then
  vim.notify("trap.nvim requires plenary.nvim", vim.log.levels.ERROR)
  return
end

-- Define a function to setup highlights after theme detection
local function setup_highlights()
  -- Get colors from the current colorscheme
  local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  local normal_fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg
  
  -- Define highlight groups
  local highlights = {
    -- Normal in the trap window - use normal text/bg colors
    TrapNormal = { default = true, bg = normal_bg, fg = normal_fg },
    
    -- Border highlight - match Normal background to avoid the black border
    TrapBorder = { default = true, bg = normal_bg, fg = normal_fg },
    
    -- Title highlight - this could be made more distinctive if desired
    TrapTitle = { default = true, bg = normal_bg, fg = normal_fg, bold = true },
  }
  
  -- Setup highlight groups
  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

-- Setup highlights immediately
setup_highlights()

local trap = {}

-- Get trap file path
local function get_trap_file_path()
  -- Store in plugin directory
  return vim.fn.stdpath("data") .. "/trap/trap.md"
end

-- Check if content should be cleared (older than 7 days)
local function should_clear_content()
  local file_path = get_trap_file_path()

  -- Check if file exists
  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    return false
  end

  -- Get current time and file modification time
  local current_time = os.time()
  local mod_time = stat.mtime.sec

  -- Calculate days difference
  local days_diff = (current_time - mod_time) / (60 * 60 * 24)

  -- Clear if older than 7 days
  return days_diff >= 7
end

-- Create trap directory if it doesn't exist
local function ensure_trap_directory()
  local dir_path = vim.fn.fnamemodify(get_trap_file_path(), ":h")

  if vim.fn.isdirectory(dir_path) == 0 then
    vim.fn.mkdir(dir_path, "p")
  end
end

-- Check and auto-clear on startup
local function check_on_startup()
  if should_clear_content() then
    trap.clear()
  end
end

-- Find trap buffer if it exists
function trap.find()
  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match(get_trap_file_path() .. "$") then
        return buf
      end
    end
  end
  return nil
end

-- Setup trap buffer with metadata
local function setup_buffer(buf)
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "buftype", "")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "autowrite", true)
  
  -- Set buffer variables (for safer closing)
  vim.api.nvim_buf_set_var(buf, "trap_managed", true)
  
  -- Load content from trap file
  if vim.fn.filereadable(get_trap_file_path()) == 1 then
    local lines = vim.fn.readfile(get_trap_file_path())
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modified", false)
  end
  
  return buf
end

-- Open trap file in a floating window using plenary
function trap.open()
  ensure_trap_directory()
  local file_path = get_trap_file_path()
  
  -- Check if file exists and has content
  local stat = vim.loop.fs_stat(file_path)
  if not stat or stat.size == 0 then
    -- Initialize file with header
    local file = io.open(file_path, "w")
    if file then
      file:write("# trap\n\n")
      file:close()
    end
  end

  -- Look for existing trap buffer or create a new one
  local trap_buf = trap.find()
  if not trap_buf then
    trap_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(trap_buf, file_path)
    trap_buf = setup_buffer(trap_buf)
  end
  
  -- Calculate dimensions for the popup
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  -- Create the popup/floating window with theme-aware highlights
  local win_id, win = popup.create(trap_buf, {
    title = "trap",
    highlight = "TrapNormal",
    borderhighlight = "TrapBorder",
    titlehighlight = "TrapTitle",
    line = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = width,
    minheight = height,
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
  })
  
  -- Additional buffer settings to prevent "No write since last change" errors
  vim.api.nvim_buf_set_option(trap_buf, "buftype", "")  -- Make it a normal buffer
  vim.api.nvim_buf_set_option(trap_buf, "autowrite", true)  -- Auto write when leaving buffer
  
  -- Store the window ID in a global variable for the TrapSave command to use
  trap.current_win = win_id
  trap.current_buf = trap_buf
  
  -- Create autocmd to automatically save the trap buffer when leaving it or when Neovim tries to quit
  vim.api.nvim_create_autocmd({"BufLeave", "VimLeave"}, {
    buffer = trap_buf,
    callback = function()
      if trap_buf and vim.api.nvim_buf_is_valid(trap_buf) and vim.api.nvim_buf_get_option(trap_buf, "modified") then
        -- Save buffer content to file
        local lines = vim.api.nvim_buf_get_lines(trap_buf, 0, -1, false)
        local file = io.open(file_path, "w")
        if file then
          file:write(table.concat(lines, "\n"))
          file:close()
          vim.api.nvim_buf_set_option(trap_buf, "modified", false)
        end
      end
    end,
    group = vim.api.nvim_create_augroup("TrapAutoSave", { clear = true }),
  })
  
  return win_id
end

-- Clear trap file content
function trap.clear()
  ensure_trap_directory()
  local file_path = get_trap_file_path()

  -- Write header to file
  local file = io.open(file_path, "w")
  if file then
    file:write("# trap\n\n")
    file:close()
  end
  
  -- Update buffer if it's open
  local buf = trap.find()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"# trap", "", ""})
    vim.api.nvim_buf_set_option(buf, "modified", false)
  end
end

-- Shut trap window (save and close)
function trap.shut()
  -- Check if a trap buffer is currently open
  if not trap.current_buf or not vim.api.nvim_buf_is_valid(trap.current_buf) then
    vim.notify("No trap buffer open to shut", vim.log.levels.ERROR)
    return false
  end
  
  -- Get buffer contents
  local lines = vim.api.nvim_buf_get_lines(trap.current_buf, 0, -1, false)
  local file_path = get_trap_file_path()
  
  -- Save contents to file
  local file = io.open(file_path, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:close()
    
    -- Mark buffer as not modified to prevent "No write since last change" errors
    vim.api.nvim_buf_set_option(trap.current_buf, "modified", false)
    
    -- Close window
    if trap.current_win and vim.api.nvim_win_is_valid(trap.current_win) then
      vim.api.nvim_win_close(trap.current_win, true)
      trap.current_win = nil
      trap.current_buf = nil
    end
    
    vim.notify("Trap saved and closed", vim.log.levels.INFO)
    return true
  else
    vim.notify("Error saving trap file", vim.log.levels.ERROR)
    return false
  end
end

-- Toggle the trap window (open if closed, close if open)
function trap.toggle()
  -- Check if trap is currently open
  if trap.current_win and vim.api.nvim_win_is_valid(trap.current_win) then
    -- Trap is open, so shut it
    return trap.shut()
  else
    -- Trap is closed, so open it
    trap.open()
    return true
  end
end

-- Setup function to be called on startup
function trap.setup()
  -- Reset highlights to match current theme
  setup_highlights()
  
  -- Set up autocmd to refresh highlights when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      setup_highlights()
    end,
    group = vim.api.nvim_create_augroup("TrapHighlightRefresh", { clear = true }),
  })
  
  -- Handle QuitPre to ensure trap buffer is saved before Neovim quits
  vim.api.nvim_create_autocmd("QuitPre", {
    callback = function()
      if trap.current_buf and vim.api.nvim_buf_is_valid(trap.current_buf) and vim.api.nvim_buf_get_option(trap.current_buf, "modified") then
        -- Save the trap file
        local file_path = get_trap_file_path()
        local lines = vim.api.nvim_buf_get_lines(trap.current_buf, 0, -1, false)
        local file = io.open(file_path, "w")
        if file then
          file:write(table.concat(lines, "\n"))
          file:close()
          vim.api.nvim_buf_set_option(trap.current_buf, "modified", false)
        end
      end
    end,
    group = vim.api.nvim_create_augroup("TrapQuitHandler", { clear = true }),
  })
  
  -- Create commands
  vim.api.nvim_create_user_command('TrapClear', function()
    trap.clear()
  end, {})
  
  -- Command to toggle trap window (open if closed, close if open)
  vim.api.nvim_create_user_command('TrapToggle', function()
    trap.toggle()
  end, {})

  -- Check for old content on startup
  ensure_trap_directory()
  check_on_startup()
end

return trap
