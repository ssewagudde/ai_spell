# AI Spell - Neovim Proofreading Plugin

A Neovim plugin that uses LLM APIs to proofread and improve the clarity of text in your buffers.

## Features

- Proofread entire buffer content using LLM APIs
- Configurable API endpoints (supports Ollama and other OpenAI-compatible APIs)
- Automatic text replacement with improved version
- Simple keybinding and command interface

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add this to your Lazy plugin configuration:

```lua
return {
  {
    "your-username/ai-spell", -- Replace with your GitHub repo
    -- dir = "/path/to/ai-spell", -- Use this for local development
    config = function()
      require('ai-spell').setup({
        -- Optional: Override defaults
        model = "llama3.2",
        timeout = 30000,
        temperature = 0.1,
        -- api_url and api_key are automatically read from environment variables
      })
    end,
  },
}
```

### For Local Development

```lua
return {
  {
    dir = "/path/to/ai-spell", -- Local path to plugin
    config = function()
      require('ai-spell').setup()
    end,
  },
}
```

## Configuration

The plugin automatically reads environment variables:
- `LLM_BASE_URL` - API endpoint URL
- `LLM_API_KEY` - API key for authentication

Default configuration:

```lua
require('ai-spell').setup({
  api_url = vim.env.LLM_BASE_URL or "http://localhost:11434/api/generate",
  api_key = vim.env.LLM_API_KEY,                   -- Optional API key
  model = "llama3.2",                              -- Model name
  timeout = 30000,                                 -- Request timeout in ms
  max_tokens = 4096,                               -- Maximum response tokens
  temperature = 0.1,                               -- LLM temperature
})
```

### Environment Variables

Set these in your shell:

```bash
export LLM_BASE_URL="http://localhost:11434/api/generate"
export LLM_API_KEY="your-api-key-here"  # Optional for local APIs
```

### For OpenAI API

```lua
require('ai-spell').setup({
  api_url = "https://api.openai.com/v1/chat/completions",
  model = "gpt-4",
  -- You'll need to modify the API request format in the code for OpenAI
})
```

## Usage

### Commands

- `:AISpellCheck` - Proofread the current buffer
- `:AISpellSetup` - Reconfigure the plugin

### Keybindings

- `<leader>sp` - Default keybinding for proofreading (can be customized)

### Custom Keybinding

```lua
vim.keymap.set('n', '<leader>pr', ':AISpellCheck<CR>', { desc = 'Proofread buffer' })
```

## How It Works

1. Extracts all content from the current buffer
2. Sends it to the configured LLM API with a proofreading prompt
3. Parses the response to extract the improved text from `<copy>` tags
4. Replaces the buffer content with the proofread version

## Requirements

- Neovim 0.7+
- `curl` command available in PATH
- Running LLM API server (like Ollama) or API key for cloud services

## Troubleshooting

- Ensure your LLM API server is running and accessible
- Check the API URL and model name in your configuration
- Use `:messages` to see detailed error information
- The plugin will show the full API response if it can't extract the corrected text

## License

MIT