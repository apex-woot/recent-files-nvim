if exists('g:loaded_recent_files') | finish | endif
let g:loaded_recent_files = 1
lua require("telescope._extensions.recent_files")
