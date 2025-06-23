local M = {}

local function build_api_url()
	local base_url = vim.env.LLM_BASE_URL or "http://localhost:11434"
	
	-- If it already has an endpoint, use as-is
	if base_url:match("/api/generate") or base_url:match("/chat/completions") then
		return base_url
	end
	
	-- If it looks like an OpenAI-style base URL, append chat/completions
	if base_url:match("^https?://") then
		return base_url .. "/chat/completions"
	end
	
	-- Default to Ollama format
	return base_url .. "/api/generate"
end

local config = {
	api_url = build_api_url(),
	api_key = vim.env.LLM_API_KEY,
	model = "bedrock-haiku",
	timeout = 30000,
	max_tokens = 4096,
	temperature = 0.1,
}

local function get_buffer_content()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

local function append_to_buffer(content)
	local separator = "\n\n--- AI PROOFREAD VERSION ---\n\n"
	local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local new_content = table.concat(current_lines, "\n") .. separator .. content
	local lines = vim.split(new_content, "\n")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function extract_copy_content(response)
	local copy_start = response:find("<copy>")
	local copy_end = response:find("</copy>")

	if copy_start and copy_end then
		copy_start = copy_start + 6
		return response:sub(copy_start, copy_end - 1):gsub("^%s*", ""):gsub("%s*$", "")
	end

	return nil
end

local function make_api_request(text, callback)
	local prompt = string.format(
		[[Here are the steps to follow:
Read the message provided within the <input tags> tags carefully.

Analyse the message to determine if it is clear, well-structured, and easy to understand. Consider factors such as grammar, sentence structure, word choice, and overall coherence.

If you find any areas that could be improved for better clarity or understandability, provide specific suggestions on how to rephrase or restructure those parts.

If the message is already clear and understandable, simply state that no changes are needed.

Once you have evaluated the message and provided any suggestions, write the evaluated message within <copy> tags, incorporating your suggested changes if applicable.

Please provide your reasoning or justification for any suggestions before presenting the evaluated message. 

Here is the input text:
<input text>
%s
</input text>]],
		text
	)

	local data
	if config.api_url:match("chat/completions") then
		-- OpenAI/LiteLLM format
		data = vim.fn.json_encode({
			model = config.model,
			messages = {
				{
					role = "user",
					content = prompt,
				},
			},
			max_tokens = config.max_tokens,
			temperature = config.temperature,
		})
	else
		-- Ollama format
		data = vim.fn.json_encode({
			model = config.model,
			prompt = prompt,
			stream = false,
			options = {
				temperature = config.temperature,
				num_predict = config.max_tokens,
			},
		})
	end

	local headers = '-H "Content-Type: application/json"'
	if config.api_key then
		headers = headers .. ' -H "Authorization: Bearer ' .. config.api_key .. '"'
	end

	local cmd = string.format(
		'curl -s -X POST "%s" %s -d %s --max-time %d',
		config.api_url,
		headers,
		vim.fn.shellescape(data),
		math.floor(config.timeout / 1000)
	)
	
	print("Using API URL:", config.api_url)
	print("Full curl command:", cmd)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data_lines)
			if data_lines and #data_lines > 0 then
				local response_text = table.concat(data_lines, "")
				if response_text ~= "" then
					print("Raw API response:", response_text)
					local ok, response = pcall(vim.fn.json_decode, response_text)
					if ok and response then
						local content
						if response.response then
							-- Ollama format
							content = response.response
						elseif response.choices and response.choices[1] and response.choices[1].message then
							-- OpenAI/LiteLLM format
							content = response.choices[1].message.content
						end

						if content then
							callback(nil, content)
						else
							print("Unexpected response format:", vim.inspect(response))
							callback("Unexpected response format", nil)
						end
					else
						print("JSON decode failed. Error:", vim.inspect(response))
						callback("Failed to parse API response: " .. tostring(response), nil)
					end
				end
			end
		end,
		on_stderr = function(_, data_lines)
			if data_lines and #data_lines > 0 then
				local error_text = table.concat(data_lines, "")
				if error_text ~= "" then
					callback("API request failed: " .. error_text, nil)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				callback("API request failed with exit code: " .. exit_code, nil)
			end
		end,
	})
end

function M.proofread_buffer()
	local content = get_buffer_content()

	if content == "" then
		vim.notify("Buffer is empty", vim.log.levels.WARN)
		return
	end

	vim.notify("Proofreading buffer...", vim.log.levels.INFO)

	make_api_request(content, function(err, response)
		if err then
			vim.notify("Error: " .. err, vim.log.levels.ERROR)
			return
		end

		local corrected_text = extract_copy_content(response)
		if corrected_text then
			append_to_buffer(corrected_text)
			vim.notify("Proofread version appended to buffer", vim.log.levels.INFO)
		else
			vim.notify("Could not extract corrected text from response", vim.log.levels.WARN)
			print("Full response:")
			print(response)
		end
	end)
end

function M.setup(opts)
	if opts then
		config = vim.tbl_deep_extend("force", config, opts)
	end

	vim.notify("AI Spell plugin configured", vim.log.levels.INFO)
end

return M

