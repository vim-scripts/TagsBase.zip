" TagsBase for Vim: plugin to make a mini database of tags in the current file
" this is then used to create a menu and to offer additional 'smart'
" functionality like finding the name of the current function.
" This is a megre of the TagsMenu.vim plugin from  Jay Dickon Glanville <jayglanville@home.com>
" and the ctags.vim script from Alexey Marinichev <lyosha@lyosha.2y.net>
" Last Modified: 1 Octobre 2001
" Maintainer: Benoit Cerrina, <benoit.cerrina@writeme.com>
" Location: http://benoitcerrina.dnsalias.org/vim/TagsBase.html.
" Version: 0.7.1
" See the accompaning documentation file for information on purpose,
" installation, requirements and available options.
" License: this is in the public domain.

" prevent multiple loadings ...
if exists("loaded_TagsBase_perl")
	finish
endif
let loaded_TagsBase_perl = 1

" function to set a global variable if it is not already set
function! s:TagsBaseSet(varname, varvalue)
	if !exists(a:varname)
		execute "let ". a:varname . " = '" . a:varvalue ."'"
	endif
endfunction

call s:TagsBaseSet('g:TagsBase_Perl_pattern','^(?!!)([^\t]*)\t[^\t]*\t(.*);"\t([^\t]*)\tline:(\d*).*$')
call s:TagsBaseSet('g:TagsBase_Perl_namePar','$1')
call s:TagsBaseSet('g:TagsBase_Perl_exprPar','$2')
call s:TagsBaseSet('g:TagsBase_Perl_typePar','$3')
call s:TagsBaseSet('g:TagsBase_Perl_linePar','$4')
perl << EOF
$^W=1;
$TagsBase_Perl_pattern=VIM::Eval('g:TagsBase_Perl_pattern');
$TagsBase_Perl_typePar=VIM::Eval('g:TagsBase_Perl_typePar');
$TagsBase_Perl_namePar=VIM::Eval('g:TagsBase_Perl_namePar');
$TagsBase_Perl_linePar=VIM::Eval('g:TagsBase_Perl_linePar');
sub ParseTag
{
	$_=VIM::Eval('a:line');
	/$TagsBase_Perl_pattern/o;
	#build the result using eval to get the value of the match
	my $name = eval($TagsBase_Perl_namePar);
	my $type = eval($TagsBase_Perl_typePar);
	my $line = eval($TagsBase_Perl_linePar);
	VIM::DoCommand("let name = '$name'");
	VIM::DoCommand("let type = '$type'");
	VIM::DoCommand("let line = '$line'");
}
EOF
