" TagsBase for Vim: plugin to make a mini database of tags in the current file
" this is then used to create a menu and to offer additional 'smart'
" functionality like finding the name of the current function.
" This is a megre of the TagsMenu.vim plugin from  Jay Dickon Glanville <jayglanville@home.com>
" and the ctags.vim script from Alexey Marinichev <lyosha@lyosha.2y.net>
" Last Modified: 1 Octobre 2001
" Maintainer: Benoit Cerrina, <benoit.cerrina@writeme.com>
" Location: http://benoitcerrina.dnsalias.org/vim/TagsBase.html.
" Version: 0.9
" See the accompaning documentation file for information on purpose,
" installation, requirements and available options.
" License: this is in the public domain.

" prevent multiple loadings ...
if exists("loaded_TagsBase")
	finish
endif
let loaded_TagsBase = 1

" function to set a global variable if it is not already set
function! s:TagsBaseSet(varname, varvalue)
	if !exists(a:varname)
		execute "let ". a:varname . " = '" . a:varvalue ."'"
	endif
endfunction



" COMMANDS:
" commands accessible from outside the plugin to manipulate the TagsBase
" to gain access to the name of the current tag in the title string
" use this command
command! TagsBaseTitle call <SID>TBTitle()
command! -nargs=1 -complete=tag TagsBaseTag :call <SID>SimpleGoToTag('<args>')
command! TagsBaseRebuild :call <SID>TagsBase_Rebuild()
command! TagsBaseDump :call <SID>TagsBase_DumpTags()
command! TagsWindow :call <SID>TagWindow()
"command! TagsBaseCleanUp :call <SID>CleanupStuff()

" ------------------------------------------------------------------------
" AUTO COMMANDS: things to kick start the script
aug TagsBase
autocmd BufEnter * call <SID>TagsBase_checkFileType()
set updatetime=600
autocmd VimLeavePre * call <SID>CleanupStuff()
autocmd CursorHold * call <SID>TitleHandler()
aug END


" ------------------------------------------------------------------------
" OPTIONS: can be set to define behaviour

" Does this script produce debugging information?

" Are the tags grouped and submenued by tag type?
call s:TagsBaseSet('g:TagsBase_groupByType','1')
" Does this script get automaticly run?
call s:TagsBaseSet('g:TagsBase_ACMode','1')
" Prefixes for the tags files
call s:TagsBaseSet('g:TagsBase_prefix','.tb.')
" Sufixes for the tags files
call s:TagsBaseSet('g:TagsBase_sufix','.tags')
" Delete the tags file on exit? 0 no cleanup 1 cleanup the files
" created in a temp directory, 2 clean everything
call s:TagsBaseSet('g:TagsBase_CleanUp','1')
" prefix to the titlestring
call s:TagsBaseSet('g:TagsBase_TitlePrefix','%t%( %M%)%( (%{expand("%:~:.:h")})%)%( %a%)%=')
call s:TagsBaseSet('g:TagsBase_MaxMenuSize', 20)


"TAGS PARSING OPTIONS:
"variables which can be used to customize the way the plugin
"parse tags beware they are very closely related one to another
"and changing the value of one and note the others is
"dangerous
"
"this is the command used to launch ctags. The --fields result in additional
"information being appended to the tag format, those are then used to build
"the menu and find the value of the tag preceding a given line
call s:TagsBaseSet('g:TagsBase_ctagsCommand',"ctags --fields=Kn -o ")
call s:TagsBaseSet('g:TagsBase_menuName', "Ta&gs")
if has('perl')
	call s:TagsBaseSet('g:TagsBase_pattern','^(?!!)([^\t]*)\t([^\t]*)\t(.*);"\t([^\t]*)\tline:(\d*).*$')
	"the following pattern should work with perl /x but it doesn't when embedded
	"		$pattern = '
	"						^					#parse the whole line
	"						(?!!)				#! is a comment fail to match
	"						([^\t]*)\t 			#first tab delimited field is name
	"						[^\t]*\t 			#second tab delimite field is file, ignored
	"						(.*);				#up to the colon the expression to jump to
	"						"					#comment sign for vi here comes additional info
	"						\t([^\t]*)\t 		#the type of the tag
	"						line:(\d*).* 		#the line number
	"						$					#end of line and of match
	"					';
	"
	call s:TagsBaseSet('g:TagsBase_namePar','$1')
	call s:TagsBaseSet('g:TagsBase_filePar','$2')
	call s:TagsBaseSet('g:TagsBase_exprPar','$3')
	call s:TagsBaseSet('g:TagsBase_typePar','$4')
	call s:TagsBaseSet('g:TagsBase_linePar','$5')
	source <sfile>:p:h/perl/TagsBase.vim
else
"GetVimIndent	C:\vim\vim60\indent\vim.vim	/^function GetVimIndent()$/;"	function	line:20
"this is the type of line matched by the following pattern"
"this can be overriden but the parenthesis must still have the meaning in the
"following variables
	call s:TagsBaseSet('g:TagsBase_pattern','^\([^\t]\{-}\)\t[^\t]\{-}\t\(.\{-}\);"\t\([^\t]*\)\tline:\(\d*\).*$')
	call s:TagsBaseSet('g:TagsBase_namePar','\1')
	call s:TagsBaseSet('g:TagsBase_exprPar','\2')
	call s:TagsBaseSet('g:TagsBase_typePar','\3')
	call s:TagsBaseSet('g:TagsBase_linePar','\4')
endif
" ------------------------------------------------------------------------
" SCRIPT VARIABLES: constants and variables who's scope is limited to this
" script, but not limited to the inside of a method.

" The name of the menu
" This is only used if you don't have perl if you do look at line 77 of
" perl/TagsBase.vim
" the name of the previous tag recognized
let s:previousTag = ""
" the count of the number of repeated tags
let s:repeatedTagCount = 0
" s:length is the length of a field in the b:lines array
" s:length is one greater than the length of maximum line number.
let s:length = 8
" strlen(spaces) must be at least s:length.
let s:spaces = '               '
" list of files to delete at exit
let s:ToDel = ''


" ---------------------------------------------------------------------
"  RUNTIME CONFIGURATION:
"  some initialisation depending on the environment

if match(&shell, 'sh', '') == -1
	let s:slash='\'
else
	let s:slash='/'
endif

let s:tempDir=fnamemodify(tempname(),":p:h")


"helper fonction for runtime configuration
"a:var is the name of a globale variable which
"should hold the name of an executable program
"a:unix is the unix name of that program,
"a:ms is the name of that program or dos command in the Ms world
"a:msg is a last resort message describing the program
function! s:TestProg(var, unix, ms, msg)
	if exists(a:var)
		exe "let loc = '" . a:var ."'"
		if executable(loc)
			return
		endif
	endif
	if executable(a:unix)
		exe "let " . a:var . " = '" . a:unix . "'"
	elseif has('win32') || has('win95') || has('win16') || has('dos32') || has('dos16')
		exe "let " . a:var . " = '" . a:ms . "'"
	else
		exe "let " . a:var . " = inputdialog('Please enter location of a program to ". a:msg . ":')"
	endif
endfunction




call s:TestProg("g:TagsBase_CatProg", 'cat', 'type', 'print a file on the console')
"I know use the delete command"
"call s:TestProg("g:TagsBase_rmProg", 'rm', 'del', 'delete a file')

" ------------------------------------------------------------------------
" SCRIPT SCOPE FUNCTIONS: functions with a local script scope
" (not used in the runtime config part)


" This function is called everytime a filetype is set.  All it does is
" check the filetype setting, and if it is one of the filetypes recognized
" by ctags, then the TagsBase_Rebuild() function is called.  However, the
" g:TagsBase_ACMode <= can veto the auto execution.
"
function! s:TitleHandler()
	if (exists('b:lines') || has('perl')) &&  exists("s:titleOn") && s:titleOn && g:TagsBase_ACMode > 1
		let &titlestring= g:TagsBase_TitlePrefix . TagsBase_GetTagType(line( ".")). "  " .TagsBase_GetTagName(line("."))
	endif
endfunction

function! s:TBTitle()
	if exists("s:titleOn") && s:titleOn
		"stop title handler
		let s:titleOn=0
		"restore title
		if exists("b:titlestring")
			let &titlestring=b:titlestring
		else
			let &titlestring=""
		endif
		if g:TagsBase_ACMode == 2
			let g:TagsBase_ACMode = 1
		elseif g:TagsBase_ACMode == 3
			let g:TagsBase_ACMode = 0
		endif
	else
		"save title
		let b:titlestring=&titlestring
		"start title handler
		let s:titleOn=1
		if g:TagsBase_ACMode < 2
			if g:TagsBase_ACMode == 1
				let g:TagsBase_ACMode = 2
			elseif g:TagsBase_ACMode == 0
				let g:TagsBase_ACMode = 3
			endif
		endif
	endif
endfunction


function! s:TagsBase_checkFileType()
	if g:TagsBase_ACMode == 3
		return
	endif
	" sorry about the bad form of this if statement, but apparently, the
	" expression needs to be terminated by an EOL. (I could use if/elseif...)
	if  (&ft == "asm") || (&ft == "awk") || (&ft == "c") || (&ft == "cpp") || (&ft == "sh") || (&ft == "cobol") || (&ft == "eiffel") || (&ft == "fortran") || (&ft == "java") || (&ft == "lisp") || (&ft == "make") || (&ft == "pascal") || (&ft == "perl") || (&ft == "php") || (&ft == "python") || (&ft == "rexx") || (&ft == "ruby") || (&ft == "scheme") || (&ft == "tcl") || (&ft == "vim") || (&ft == "cxx")
		call s:TagsBase_Rebuild()
	endif
endfunction

function! s:AddFileArg(iCommand, iFileArg)
	return a:iCommand . ' "' . a:iFileArg . '"'
endfunction
" Clean up the files if required
function! s:CleanupStuff()
	"delete all files in s:ToDel list
	while strlen(s:ToDel) > 0
		let delimidx = stridx(s:ToDel, "\n")
		let currentFile = strpart(s:ToDel, 0, delimidx)
		if delete(currentFile) != 0
			echo 
		endif
		"		let lCommand = s:AddFileArg(g:TagsBase_rmProg, currentFile)
		"		let lCommand = substitute(lCommand, '[/\\]', s:slash, 'g')
		"		call system(lCommand)
		let s:ToDel = strpart(s:ToDel, delimidx+1)
	endwhile
endfunction

" Creates a file
" name is the name of the file to create, mode is 1 for files in a temp
" directory 2 for files in a normal directory
function! s:SetFileName(iName, iMode)
	let b:fileName = a:iName
	if g:TagsBase_CleanUp >= a:iMode
		"use the variable script dictionary as a hashtable
		let s:ToDel = s:ToDel . b:fileName . "\n"
	endif
endfunction

" Creates the tag file associated with a buffer and stores its name in
" b:fileName
" if tmp==1 create a temporary tag file if tmp=0 tries to create a permanent
" one
" returns 1 if the file was regenerated 0 otherwise
function! s:CreateFile(tmp)
	"build file name"
	if !exists("b:fileName") || b:fileName == "" || a:tmp == 1
		let dir= fnamemodify(@%,":p:h")
		let name = fnamemodify(@%, ":t")
		let b:fileName = dir . "/" . g:TagsBase_prefix . name . g:TagsBase_sufix
		if a:tmp == 1 || (!filewritable(b:fileName) && !filewritable(dir))
			let b:fileName = s:tempDir . "/" . g:TagsBase_prefix . name . g:TagsBase_sufix
			call s:SetFileName(b:fileName, 1)
		else
			call s:SetFileName(b:fileName, 2)
		endif
	endif
	" execute the ctags command on the current file
	if !filereadable(b:fileName) || getftime(b:fileName) < getftime(@%)
		let lCommand = s:AddFileArg(g:TagsBase_ctagsCommand . ' ', b:fileName)
		let lCommand = s:AddFileArg(lCommand . ' ', fnamemodify(bufname("%"), ":p"))
		let lCommand = substitute(lCommand, '[/\\]', s:slash, 'g')
		"vim uses the relative path relative to the path of the tag file while
		"ctags relative to the path when running ctags, therefore we need to
		"change the directory
		let dir=fnamemodify(b:fileName , ":p:h")
		let olddir=getcwd()
		silent! execute "cd " . dir
		silent! call system( lCommand )
		silent! execute "cd " . olddir
		"check that the file was written or try a temp file (this is to
		"correct the nt acl bug)"
		if (!filereadable(b:fileName) || getftime(b:fileName) < getftime(@%))
			if a:tmp==1
				return 0   "stop trying
			endif
			call s:CreateFile(1)
		endif
		let fileName = b:fileName   "local variable because we'll switch buffer
		return 1
	else
		return 0
	endif
endfunction


" This is the function that actually calls ctags, parses the output, and
" creates the menus.
function! s:TagsBase_Rebuild()

	let start = localtime()

	if !s:CreateFile(0) && exists("b:TagsBase_menuCommand")
		"tags file didn't change therefore no need to recompute the menu
		execute b:TagsBase_menuCommand
		return
	endif	
	call s:InitializeMenu()
	if (has("perl"))
		perl TagsBase::BuildBase 
		let time = localtime() - start
		""echo "tags built in " . time
		return
	endif
	"check if the file is readable
	if !filereadable(b:fileName)
		return
	endif
	"read the file in a variable
	let command = s:AddFileArg(g:TagsBase_CatProg.' ', b:fileName)
	let command = substitute(command, '[/\\]', s:slash, 'g')

	let ctags = system(command)

	" loop over the entire file, parsing each line.  Apparently, this can be
	" done with a single command, but I can't remember it.
	let b:lines = ''
	let lineNum = 0
	while strlen(ctags) > 0
		let delimIdx =  stridx(ctags, "\n")
		"case there is no ending \n
		if delimIdx == -1
			let delimIdx = strlen(ctags)
		endif
		let current = strpart(ctags, 0, delimIdx)
		if current[0] != '!'
			call s:ParseTag(current)
			call s:MakeMenuEntry()
			call s:MakeTagBaseEntry()
		endif
		let ctags = strpart(ctags, delimIdx+1)
		let lineNum = lineNum +1
		if lineNum % 500 == 0
			echo lineNum . " line processed."
		endif
	endwhile
	let time = localtime() - start
	echo "tags built in " . time
	let b:lines = b:lines."9999999"
	execute b:TagsBase_menuCommand
endfunction



" Initializes the menu by erasing the old one, creating a new one, and
" starting it off with a "Rebuild" command
function! s:InitializeMenu()

	" first, lets remove the old menu
	let s:previousTag = ""
	let s:repeatedTagCount = 0
	let b:TagsBase_menuCommand =  "amenu " . g:TagsBase_menuName . ".subname :echo\\ foo\n"
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand . "aunmenu " . g:TagsBase_menuName ."\n"
	"	and now, add the top of the new menu
	
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand .  
				\ "amenu <silent>" . g:TagsBase_menuName . ".&Open\\ Tags\\ Buffer :TagsWindow<CR><CR>\n"
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand .  
				\ "amenu <silent>" . g:TagsBase_menuName . ".&Rebuild\\ Tags\\ Base :TagsBaseRebuild<CR><CR>\n"
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand .  
				\ "amenu <silent>" . g:TagsBase_menuName . ".&Toggle\\ Title\\ Autocommand :TagsBaseTitle<CR><CR>\n"     
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand .  
				\ "amenu " . g:TagsBase_menuName . ".-SEP- :\n"

endfunction

"this function parses a tag entry and set the appropriate script variable
"s:name       name of the tag
"s:type       type of the tag
"s:expression expression used to find the tag
"s:line       line where the tag is defined
function! s:ParseTag(line)
	let s:name = ""
	let s:type = ""
	let s:expression = ""
	let s:line = ""

	if a:line[0] == "!"
		return
	endif

	let s:name = substitute(a:line, g:TagsBase_pattern, g:TagsBase_namePar , '')
	let s:expression = substitute(a:line, g:TagsBase_pattern, g:TagsBase_exprPar, '')
	let s:type = substitute(a:line, g:TagsBase_pattern, g:TagsBase_typePar, '')
	let s:line = substitute(a:line, g:TagsBase_pattern, g:TagsBase_linePar, '')

	if match( s:expression, "[0-9]" ) == 0
		" this expression is a line number not a pattern so prepend line number
		" with : to make it an absolute line command not a relative one
		let s:expression = ":" . s:expression
	else
		let s:expression = ":0" . s:expression
	endif
endfunction

" This function takes a string (assumidly a line from a tag file format) and
" parses out the pertinent information, and makes a tag entry in the tag
" menu.
function! s:MakeMenuEntry()
	"copy other the name since we may need to change it
	"if the tag is overloaded
	let name = s:name
	" is this an overloaded tag?
	if name == s:previousTag
		" it is overloaded ... augment the name
		let s:repeatedTagCount = s:repeatedTagCount + 1
		let name = name . "\\ (" . s:repeatedTagCount . ")"
	else
		let s:repeatedTagCount = 0
		let s:previousTag = name
	endif

	" build the menu command
	let menu = "amenu " . g:TagsBase_menuName
	if g:TagsBase_groupByType
		let menu = menu . ".&" . s:type
	endif
	let menu = menu . ".&" . name
	if !g:TagsBase_groupByType
		let menu = menu . "<tab>" . s:type
	endif
	let menu = menu . " " . ":call TagsBase_GoToTag('". s:name . "', " . s:repeatedTagCount . ")<CR><cr>\n"
	" escape some pesky characters
	" this is probably not usefull anymore since I doubt there are any
	" characters to escape in a tagname
	let b:TagsBase_menuCommand = b:TagsBase_menuCommand .  menu
endfunction

" This function builds an array of tag names.  b:lines contains line numbers;
" b:l<number> is the tag value for the line <number>.
function! s:MakeTagBaseEntry()
	let command = "let b:l".s:line. " = '".s:name."'"
	execute command
	let command = "let b:t".s:line. " = '".s:type."'"
	execute command
	let index = s:BinarySearch(s:line) + 1
	let firstpart = strpart(b:lines, 0, s:length*index)
	let middlepart = strpart(s:line.s:spaces, 0, s:length)
	let lastpart = strpart(b:lines, s:length*index, strlen(b:lines))
	let b:lines = firstpart . middlepart . lastpart
endfunction

" This function returns the tag line for given index in the b:lines array.
function! s:GetLine(i)
	return strpart(b:lines, a:i*s:length, s:length)+0
endfunction

"dump all the defined tags in order of definitions
function! s:TagsBase_DumpTags()
	if !exists("b:lines")  || match(b:lines, "^\s*9999999") != -1 || b:lines == ""
		return
	endif
	let length = strlen(b:lines)/s:length
	let i = 0
	while i < length
		let line = s:GetLine(i)
		exec "echo b:t".line. " b:l".line
		let i = i+1
	endwhile
endfunction
" This function does binary search in the array of tag names and returns
" the index of the corresponding line or the one immediately inferior.
" it is used to retrieve the tag name corresponding to a given line (cf
" TagsBase_GetTagName)
" and to keep the b:lines array sorted as it is being built
function! s:BinarySearch(curline)
	if !exists("b:lines") || match(b:lines, "^\s*9999999") != -1
		return -1
	endif

	if b:lines == ""
		return 0
	endif

	let left = 0
	let right = strlen(b:lines)/s:length

	if a:curline < s:GetLine(left)
		return -1
	endif

	while left<right
		let middle = (right+left+1)/2
		let middleline = s:GetLine(middle)

		if middleline == a:curline
			let left = middle
			break
		endif

		if middleline > a:curline
			let right = middle-1
		else
			let left = middle
		endif
	endwhile
	return left
endfunction

function! s:GetTagLine(curline)
	let index = s:BinarySearch(line)
	if index == -1
		return -1
	endif
	return s:GetLine(index)
endfunction


"retrieves the name of the last tag defined for a given line
function! TagsBase_GetTagName(curline)
	if a:curline !~ '\d\+'
		let line = line(a:curline)
	else 
		let line = a:curline
	endif
	if (has('perl'))
		exec "perl TagsBase::GetTagName " . line
		return retVal;
	endif
	let line = s:GetTagLine(line)
	if line == -1
		return ""
	endif
	exe "let valide = exists('b:l". line . "')"
	let ret = "invalid tag"
	if valide
		exe "let ret=b:l" . line
	endif
	return ret
endfunction


"retrieves the name of the last tag defined for a given line
function! TagsBase_GetTagType(curline)
	if a:curline !~ '\d\+'
		let line = line(a:curline)
	else 
		let line = a:curline
	endif
	if (has('perl'))
		exec "perl TagsBase::GetTagType " . line
		return retVal;
	endif
	let line = s:GetTagLine(line)
	if line == -1
		return ""
	endif
	exe "let valide = exists('b:l". line . "')"
	let ret = "invalid tag"
	if valide
		exe "let ret=b:t". line
	endif
	return ret
endfunction

"goes to the first tag by this name
function! s:SimpleGoToTag(iTag)
	call TagsBase_GoToTag(a:iTag, 0)
endfunction

"uses vim tags facility to jump to a tag and push the tag to the tag stack.
"restores the value of tags afterward
function! TagsBase_GoToTag(iTag, iIndex)
	let oldTag = &tags
	let &tags=escape (b:fileName, ' ')
	silent execute "ta " . a:iTag
	let index = a:iIndex
	while index > 0
		let index = index -1
		silent tn
	endwhile
	let &tags=oldTag
endfunction

function! s:TagWindow()
	let bufnr = bufnr('%')
	
	sp TagsBuffer
	let b:bufnr = bufnr
	let b:tagFile = getbufvar(b:bufnr, "fileName")
	set ft=TagsBase
	" feel in the buffer
	call s:UpdateTagBuffer(bufnr('%'))
endfunction

"assume the buffer bufnr is a tagsbase buffer and update it
function! s:UpdateTagBuffer(bufnr)
	"empty the buffer
	let buf = bufnr('%')
	exe 'b '.a:bufnr
	set modifiable
	silent 0,$del
	silent exe 'r! ctags -x ' . fnamemodify(bufname(b:bufnr), ":p")
	"reorder the buffer with line\ttype\t\tname"
	silent :%s/\(\S*\)\s\+\(\S*\)\s\+\(\S*\)\s\+\(\S*\)\s\+.*/\3\t\2\t\t\1/
	set nomodifiable
	exe 'b '. buf
endfunction

function! TagsBaseBufGotoTag()
	"get the line number
	let ln = matchstr(getline('.'), '^\d\+')
	let bufnr = b:bufnr
	quit
	exe 'b ' . bufnr
	exe ln
endfunction
