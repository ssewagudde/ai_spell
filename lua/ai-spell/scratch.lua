local M = {}

local config = {
	name = "Scratch",
	ft = function()
		if vim.bo.buftype == "" and vim.bo.filetype ~= "" then
			return vim.bo.filetype
		end
		return "markdown"
	end,
	icon = nil,
	root = vim.fn.stdpath("data") .. "/scratch",
	autowrite = true,
	filekey = {
		cwd = true,
		branch = true,
		count = true,
	},
	win = {
		width = 100,
		height = 30,
		border = "rounded",
		title_pos = "center",
		footer_pos = "center",
		zindex = 20,
	},
	template = "",
}

local function get_git_branch()
	local handle = io.popen("git branch --show-current 2>/dev/null")
	if not handle then
		return nil
	end
	local branch = handle:read("*a"):gsub("\n", "")
	handle:close()
	return branch ~= "" and branch or nil
end

local function get_file_key(opts)
	local parts = { opts.name or config.name }
	
	local ft = type(opts.ft) == "function" and opts.ft() or opts.ft or config.ft()
	if ft then
		table.insert(parts, ft)
	end
	
	if config.filekey.count and vim.v.count1 > 1 then
		table.insert(parts, tostring(vim.v.count1))
	end
	
	if config.filekey.cwd then
		local cwd = vim.fn.getcwd():gsub("/", "_"):gsub("^_", "")
		table.insert(parts, cwd)
	end
	
	if config.filekey.branch then
		local branch = get_git_branch()
		if branch then
			table.insert(parts, branch)
		end
	end
	
	return table.concat(parts, "-")
end

local function get_scratch_file(opts)
	opts = opts or {}
	local key = get_file_key(opts)
	local ft = type(opts.ft) == "function" and opts.ft() or opts.ft or config.ft()
	local ext = ft == "markdown" and "md" or ft or "txt"
	local filename = key .. "." .. ext
	return config.root .. "/" .. filename
end

local function ensure_scratch_dir()
	local dir = config.root
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
end

local function create_scratch_window(file, opts)
	opts = opts or {}
	local win_config = vim.tbl_deep_extend("force", config.win, opts.win or {})
	
	local buf = vim.fn.bufnr(file, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	
	if vim.fn.filereadable(file) == 1 then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent! edit " .. vim.fn.fnameescape(file))
		end)
	else
		local template = opts.template or config.template
		if template and template ~= "" then
			local lines = vim.split(template, "\n")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		end
	end
	
	local ft = type(opts.ft) == "function" and opts.ft() or opts.ft or config.ft()
	if ft then
		vim.api.nvim_buf_set_option(buf, "filetype", ft)
	end
	
	local width = win_config.width or 100
	local height = win_config.height or 30
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = win_config.border or "rounded",
		title = " " .. (opts.name or config.name) .. " ",
		title_pos = win_config.title_pos or "center",
		zindex = win_config.zindex or 20,
	})
	
	vim.api.nvim_win_set_option(win, "winhighlight", "NormalFloat:Normal")
	
	if config.autowrite then
		vim.api.nvim_create_autocmd("BufHidden", {
			buffer = buf,
			callback = function()
				if vim.api.nvim_buf_get_option(buf, "modified") then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("silent! write " .. vim.fn.fnameescape(file))
					end)
				end
			end,
		})
	end
	
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, false)
	end, { buffer = buf, desc = "Close scratch buffer" })
	
	if ft == "lua" then
		vim.keymap.set({ "n", "x" }, "<cr>", function()
			local lines
			if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
				local start_pos = vim.fn.getpos("'<")
				local end_pos = vim.fn.getpos("'>")
				lines = vim.api.nvim_buf_get_lines(buf, start_pos[2] - 1, end_pos[2], false)
			else
				lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			end
			
			local code = table.concat(lines, "\n")
			local chunk, err = loadstring(code)
			if chunk then
				local ok, result = pcall(chunk)
				if ok then
					if result ~= nil then
						print("Result:", vim.inspect(result))
					end
				else
					vim.notify("Error executing code: " .. tostring(result), vim.log.levels.ERROR)
				end
			else
				vim.notify("Syntax error: " .. tostring(err), vim.log.levels.ERROR)
			end
		end, { buffer = buf, desc = "Execute Lua code" })
	end
	
	return { buf = buf, win = win, file = file }
end

function M.open(opts)
	opts = opts or {}
	ensure_scratch_dir()
	
	local file = get_scratch_file(opts)
	
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local buf_name = vim.api.nvim_buf_get_name(buf)
		if buf_name == file then
			vim.api.nvim_win_close(win, false)
			return
		end
	end
	
	return create_scratch_window(file, opts)
end

function M.list()
	ensure_scratch_dir()
	local files = {}
	
	local handle = io.popen("find " .. vim.fn.shellescape(config.root) .. " -type f 2>/dev/null")
	if not handle then
		return files
	end
	
	for file in handle:lines() do
		local stat = vim.loop.fs_stat(file)
		if stat then
			local basename = vim.fn.fnamemodify(file, ":t:r")
			local ext = vim.fn.fnamemodify(file, ":e")
			
			local parts = vim.split(basename, "-")
			local name = parts[1] or "Scratch"
			local ft = ext ~= "" and ext or "txt"
			
			table.insert(files, {
				file = file,
				stat = stat,
				name = name,
				ft = ft,
				icon = nil,
				cwd = nil,
				branch = nil,
				count = nil,
			})
		end
	end
	handle:close()
	
	table.sort(files, function(a, b)
		return a.stat.mtime.sec > b.stat.mtime.sec
	end)
	
	return files
end

function M.select()
	local files = M.list()
	if #files == 0 then
		vim.notify("No scratch files found", vim.log.levels.INFO)
		return
	end
	
	local items = {}
	for _, file_info in ipairs(files) do
		local display = string.format("%s (%s)", 
			vim.fn.fnamemodify(file_info.file, ":t"), 
			file_info.ft)
		table.insert(items, {
			text = display,
			file = file_info.file,
			ft = file_info.ft,
		})
	end
	
	vim.ui.select(items, {
		prompt = "Select scratch buffer:",
		format_item = function(item)
			return item.text
		end,
	}, function(choice)
		if choice then
			local buf = vim.fn.bufnr(choice.file, true)
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("edit " .. vim.fn.fnameescape(choice.file))
			end)
			vim.api.nvim_set_current_buf(buf)
		end
	end)
end

function M.setup(opts)
	if opts then
		config = vim.tbl_deep_extend("force", config, opts)
	end
end

return M