"special buffer options
setlocal buftype=nofile
set nobuflisted 		
set bufhidden=delete
set nomodifiable
set ts=8
"mapping
noremap <buffer> <silent> <2-LeftMouse> :call TagsBaseBufGotoTag()<cr>
noremap <buffer> <silent> <cr> :call TagsBaseBufGotoTag()<cr>
"commands
