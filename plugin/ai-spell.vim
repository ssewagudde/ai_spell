if exists('g:loaded_ai_spell')
  finish
endif
let g:loaded_ai_spell = 1

command! AISpellCheck lua require('ai-spell').proofread_buffer()
command! AISpellSetup lua require('ai-spell').setup()

nnoremap <silent> <Plug>AISpellCheck :AISpellCheck<CR>

if !hasmapto('<Plug>AISpellCheck')
  nmap <leader>sp <Plug>AISpellCheck
endif