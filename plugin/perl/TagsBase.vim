" TagsBase for Vim: plugin to make a mini database of tags in the current file
" this is then used to create a menu and to offer additional 'smart'
" functionality like finding the name of the current function.
" This is a megre of the TagsMenu.vim plugin from  Jay Dickon Glanville <jayglanville@home.com>
" and the ctags.vim script from Alexey Marinichev <lyosha@lyosha.2y.net>
" Last Modified: 1 Octobre 2001
" Maintainer: Benoit Cerrina, <benoit.cerrina@writeme.com>
" Location: http://benoitcerrina.dnsalias.org/vim/TagsBase.html.
" Version: 0.8.4
" See the accompaning documentation file for information on purpose,
" installation, requirements and available options.
" License: this is in the public domain.

" prevent multiple loadings ...
""if exists("loaded_TagsBase_perl")
""	finish
""endif
let loaded_TagsBase_perl = 1

" function to set a global variable if it is not already set
function! s:TagsBaseSet(varname, varvalue)
	if !exists(a:varname)
		execute "let ". a:varname . " = '" . a:varvalue ."'"
	endif
endfunction


perl << EOF
package TagsBase;  
# line 29 "perl/TagsBase.vim"
use diagnostics;
{
	package TagsBase::Base;
	##################################################
	## the object constructor (simplistic version)  ##
	##################################################
	sub new 
	{
		my $self = [];
		bless($self);           
		return $self;
	}

	##############################################
	##      access to a specific Base           ##
	## no arg that of the $curbuf with arg first##
	## arg is taken as buffer number            ##
	##############################################
	sub getBase 
	{
		my $self = shift;
		my $bufnum = shift;
		$bufnum = $main::curbuf->Number() unless $bufnum;
		return @{$self[$bufnum]};
	}

	##############################################
	#      sorts a Base                          #
	## no arg that of the $curbuf with arg first##
	## arg is taken as buffer number            ##
	##############################################
	sub sortBase
	{
		my $self = shift;
		my $bufnum = shift;
		$bufnum = $main::curbuf->Number() unless $bufnum;
		my @blines = @{$self[$bufnum]};
		@blines = sort {$a->[0] <=> $b->[0]} @blines;
		$self[$bufnum] = \@blines;
	}

	sub pushTag
	{
		my $self = shift;
		my $Tag = shift;
		my $bufnum = shift;
		$bufnum = $main::curbuf->Number() unless $bufnum;
		#my @blines = @{$self[$bufnum]};
		push @{$self[$bufnum]}, $Tag;
		#$self[$bufnum] = \@blines;
	}

	sub getTag
	{
		my $self = shift;
		my $line = shift;
		my $bufnum = shift;
		$bufnum = $main::curbuf->Number() unless $bufnum;
		#binary search
		my $left = 0;
		my @blines = @{$self[$bufnum]};
		my $right = $#blines;
		my $middle;
		my $middleline;
		for(;$left < $right;)
		{
			$middle = int(($right + $left +1) / 2);
			$middleline = $blines[$middle][0];
			if ($middleline == $line)
			{
				$left = $middle;
				last;
			}
			if ($middleline > $line)
			{
				$right = $middle -1;
			} else
			{
				$left = $middle;
			}
		}
		return $blines[$left];
	}

	sub initBase
	{
		my $self = shift;
		my $bufnum = shift;
		$bufnum = $main::curbuf->Number() unless $bufnum;
		$self[$bufnum] = [];
	}
}
{
	package TagsBase::Tag;
	sub new
	{
		my $self = [];
		return bless($self);
	}
	sub Line
	{
		my $self = shift;
		$self->[0] = shift if (@_);
		return $self[0];
	}
	sub Name
	{
		my $self = shift;
		$self->[1] = shift if (@_);
		return $self->[1];
	}
	sub Type
	{
		my $self = shift;
		$self->[2] = shift if (@_);
		return $self[2];
	}
}

$Gbase = TagsBase::Base::new();
$menuName = VIM::Eval('g:TagsBase_menuName');
$groupByType = VIM::Eval("g:TagsBase_groupByType");
$pattern=VIM::Eval('g:TagsBase_pattern');
$typePar=VIM::Eval('g:TagsBase_typePar');
$namePar=VIM::Eval('g:TagsBase_namePar');
$linePar=VIM::Eval('g:TagsBase_linePar');
$maxMenuSize = VIM::Eval('g:TagsBase_MaxMenuSize');
$maxMenuSize = 26 if ($maxMenuSize > 26 || $maxMenuSize <1);
sub logFloorMenu
{
	my $n = shift;
	return 0 unless $n;			
	return int(log($n)/log($maxMenuSize));
}


sub ComputeMenu
{
	#my $depth = logFloorMenu($#{$curSubMenuRef});
	#my $width = $maxMenuSize ** $depth;
	my $width = int(@{$curSubMenuRef} / $maxMenuSize)+1;
	#VIM::Msg("width $width");
	my $shortType = shift;
	my $curPriority;
	if ($width == 1)
	{
		my $short = 'a';
		my $priority = 1;
		for (@$curSubMenuRef)
		{
			($prevName, $repeatcount) = @{$_};
			$name=$prevName;
			$name.="($repeatcount)" if $repeatcount;
			$name =~ s/\./\\\\./g;	#for things like packages in java
			if ($localMenuName)
			{
				$menuCommand .= "\\namenu <silent> $localPriority $localMenuName.$name<tab>&$short" if ($groupByType);
				$menuCommand .= "\\namenu <silent> $localPriority $localMenuName.$name<tab> $type &$short" unless ($groupByType);
			}
			else
			{
				$menuCommand .= "\\namenu <silent> $menuName.$type<tab>&$shortType.$name<tab>&$short" if ($groupByType);
				$menuCommand .= "\\namenu <silent> $menuName.$name<tab> $type &$short" unless ($groupByType);
			}
			$menuCommand .=" :call TagsBase_GoToTag('$prevName', $repeatcount)<cr>";
			$short = chr(ord($short) + 1);
		}
	}
	else
	{
		#we need a submenu
		#VIM::Msg "Submenu case for $type";
		my $short = 'a';
		for(my $curStart = 0; $curStart <= $#{$curSubMenuRef}; $curStart+= ($width))
		{
			$curMax = $curStart + $width -1;
			$curMax = $#{$curSubMenuRef} if($curMax > $#{$curSubMenuRef});
			my $dummy;		#will hold unused repeatCount
			($prevNameSmall, $dummy) = @{@{$curSubMenuRef}[$curStart]};
			($prevNameBig, $dummy) = @{@{$curSubMenuRef}[$curMax]};
			$curPriority = ord($short);
			if ($localMenuName)
			{
				$curPriority = "$localPriority.$curPriority";
				$curMenuName = "$localMenuName.$prevNameSmall--$prevNameBig<tab>&$short";
			}
			else
			{
				if ($groupByType)
				{
					$curPriority = "500.500.$curPriority";
					$curMenuName = "$menuName.$type<tab>&$shortType.$prevNameSmall--$prevNameBig<tab>&$short";
				}
				else
				{
					$curPriority = "500.$curPriority";
					$curMenuName = " $menuName.$prevNameSmall--$prevNameBig<tab>&$short" unless ($groupByType);
				}
			}				
			$menuCommand .= "\\namenu <silent> $curPriority $curMenuName";
			$menuCommand .=" :perl TagsBase::BuildBase('$curMenuName', '$type',$curStart, $curMax, '$curPriority')<cr>";
			$short = chr(ord($short) + 1);
		}
	}
}


#parse the tags file passed as an argument
sub parseTags
{
	my $file = shift;
	die ("failed to open $file") unless open TAGS, $file;
	my $typedCount = -1 ;  	#number of parsed tags for the $localType
	my $Tag;
	while (<TAGS>)
	{
		#		$count++;	
		next if (substr($_, 0, 1) eq '!');

		#parse
		#		if someone can tell me why this pattern doesn't work I'd be very glad
		#		$pattern = '
		#						^				#parse the whole line
		#						(?!!)				#! is a comment fail to match
		#						([^\t]*)\t 			#first tab delimited field is name
		#						[^\t]*\t 			#second tab delimite field is file, ignored
		#						(.*);				#up to the colon the expression to jump to
		#						"				#comment sign for vi here comes additional info
		#						\t([^\t]*)\t 		#the type of the tag
		#						line:(\d*).* 		#the line number
		#						$				#end of line and of match
		#					';
		next unless /$pattern/ox;
		$name = eval $namePar;
		$type = eval $typePar;
		$line = eval $linePar;
		#check for the local case
		next if ($groupByType && $localType && $type ne $localType);
		$typedCount++;
		next if ($start && $typedCount < $start);
		next if ($end && $typedCount > $end);
		#check for repeated tag
		if ($name eq $prevName)
		{	
			$repeatcount++;
		}
		else
		{
			$repeatcount = 0;
			$prevName = $name;
		}
		#build the menu structure
		if (!$groupByType || ($curSubMenuRef = $menu{$type}))		#first level of structure is type
		{
			push (@$curSubMenuRef, [$name, $repeatcount]);
		}
		else
		{
			$menu{$type} = [[$name, $repeatcount]];
		}

		#build the base command
		$Tag = TagsBase::Tag::new();
		$Tag->Name($name);
		$Tag->Line($line);
		$Tag->Type($type);
		$Gbase->pushTag($Tag) unless $localMenuName;
	}
	close TAGS;

}

#high performance version of TagsBase
#this can be called either to recompute everything
#(with no argument) or with the argument 
# 	($localMenuName, $localType, $start, $end)
#to compute only a submenu
sub BuildBase
{
	my $startTime = time();
	#use local instead of my to keep the variable available for the compute menu 
	#sub
	local $name;
	local $type;
	local $line;
	local $repeatcount = 0;
	local $prevName = "";
	local $menuCommand = "";
	my $baseCommand = "";

	my $size = 8;

	local %menu;		#hash structure to hold the menus
	local $curSubMenuRef; #scalar value to hold a reference to the current submenu
	$curSubMenuRef = [] if (!$groupByType);
	local $localMenuName;
	local $localType;
	local $start;
	local $end;
	local $localPriority;
	($localMenuName, $localType, $start, $end, $localPriority) = @_;	
	#VIM::Msg "args " . join(", ", @_);
	my $file = VIM::Eval("b:fileName");
	#VIM::Msg "file $file";
	$Gbase->initBase unless $localMenuName;
	parseTags($file);
	

	#post processing:	
	#compute menus
	local $curMax;
	ComputeMenu unless ($groupByType);
	my $short = 'a';
	while (($type, $curSubMenuRef) = each %menu) 
	{
		#additional menu depth
		next if ($localType && $type ne $localType);
		ComputeMenu $short;
		$short = chr(ord($short) + 1);

	}


	$time = time() -$startTime;
	#VIM::Msg ("Time before Vim menu command $time");
	#VIM::Msg("menu command $menuCommand");
	if ($localMenuName)
	{
		#compute the command to open the menu
		my $path = 'simalt '.join('|simalt ', $localMenuName =~ /&([a-zA-Z])/go);
		#when the menu command is local do not add it to the global command
		$menuCommand =~ s/\t/<tab>/go;
		$localMenuName =~ s/\t/<tab>/go;
	#	$menuCommand = qq!aunmenu $localMenuName | exec "$menuCommand" | popup $localMenuName!;
		$menuCommand = qq!aunmenu $localMenuName | exec "$menuCommand" | $path!;
		#VIM::Msg $menuCommand
	}
	else
	{	
		$menuCommand = qq!let b:TagsBase_menuCommand = b:TagsBase_menuCommand . "$menuCommand" | exec b:TagsBase_menuCommand!;
		#VIM::Msg $menuCommand;
	}
	VIM::DoCommand $menuCommand;
	$time = time() -$startTime;
	#VIM::Msg ("Time before Vim base command $time");


	#post processing: 
	#format blines into a fixed lenght array of sorted number
	my $time = time() - $startTime;
	#VIM::Msg("Time before sorting and formating the b:lines array $time");
	$Gbase->sortBase unless $localMenuName;
	#	VIM::Msg "blines" . join ", " , @blines;
	$time = time() - $startTime;
	#VIM::Msg ("Total Time in perl $time");
	#VIM::Msg $localMenuName if ($localMenuName);
}

sub GetTag
{
	my $line = shift;
	my @blines = $Gbase->getBase;
	my @elem = grep { $_->[0] < $line } @blines;
	return @{$elem[$#elem]};
}

#valuate the retVal variable in vim
#parameter is line of tag to found
#return is type of last tag defined before
#the param
sub GetTagType
{
	my $line = shift;
	my $elem = $Gbase->getTag($line);
	VIM::DoCommand "let retVal = '". $elem->[2]."'";
	return $elem->[2];			#for debugging
}


#valuate the retVal variable in vim
#parameter is line of tag to found
#return is name of last tag defined before
#the param
sub GetTagName
{
	my $line = shift;
	my $elem = $Gbase->getTag($line);
	VIM::DoCommand "let retVal = '" . $elem->[1]."'";
	return $elem->[1];			#for debugging
}

EOF
