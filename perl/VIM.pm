use diagnostics;
use strict;
package VIM;
sub VIM::Eval
{
	$_ = shift;
	
	print "Eval $_\n";
	
	{
		  return '^(?!!)([^\t]*)\t[^\t]*\t(.*);"\t([^\t]*)\tline:(\d*).*$' if (/g:TagsBase_pattern/);
		  return $ARGV[0] if (/b:fileName/);
		  return '$3' if (/g:TagsBase_typePar/);
		  return '$1' if (/g:TagsBase_namePar/);
		  return '$4' if (/g:TagsBase_linePar/);
		  return 'Ta&gs' if (/g:TagsBase_menuName/);
		  return $ARGV[1] if (/g:TagsBase_groupByType/);
		  return 40 if (/g:TagsBase_MaxMenuSize/);
		die "unknown eval $_"; 
	}  
}
sub VIM::Msg
{
	my $msg = shift;
	print "MSG $msg\n";
}
sub VIM::DoCommand
{
	my $package;
	my $filename;
	my $line;
    ($package, $filename, $line) = caller;
	
	my $command = shift;
	print "at $filename $line\n";
	print "DoCommand  $command\n";
}
package VIBUF;
    ##################################################
    ## the object constructor (simplistic version)  ##
    ##################################################
    sub new {
        my $_self  = shift;
		my $self = \$_self;
        bless($self);           # but see below
        return $self;
    }
    ##############################################
    ## methods to access per-object data        ##
    ##############################################
    sub Number {
        my $self = shift;
        
        return ${$self};
    }

package main;
$main::curbuf = VIBUF::new(2);	#set curbuf

1;
