package Catalyst::View::ByCode::Declare;
use strict;
use warnings;

use Devel::Declare();
# use B::Hooks::EndOfScope;
# use Data::Dump 'dump';


###### Thanks #####################################################
#                                                                 #
# Thanks to Kang-min Liu for doing 'Markapl.pm'                   #
# most of the concepts here are 'borrowed' from this great module #
# sorry for copying instead of thinking.                          #
#                                                                 #
#################################################### /Thanks ######

# these variables will get local()'ized during a parser run
our ($Declarator, $Offset);

#
# skip space symbols (if any)
#
sub skipspace {
    $Offset += Devel::Declare::toke_skipspace($Offset);
}

#
# non-destructively read next character
#
sub next_char {
    skipspace;
    my $linestr = Devel::Declare::get_linestr;
    return substr($linestr, $Offset, 1);
}

# CURRENTLY NOT NEEDED
# #
# # non-destructively read next word (=token)
# #
# sub next_word {
#     skipspace;
#     
#     if (my $length = Devel::Declare::toke_scan_word($Offset, 1)) {
#         my $linestr = Devel::Declare::get_linestr;
#         return substr($linestr, $Offset, $length);
#     }
#     return '';
# }

#
# inject something at current position
#  - with optional length
#  - at optional offset
# returns thing at inserted position before
#
sub inject {
    my $inject = shift;
    my $length = shift || 0;
    my $offset = shift || 0;

    my $linestr  = Devel::Declare::get_linestr;
    my $previous = substr($linestr, $Offset+$offset, $length);
    substr($linestr, $Offset+$offset, $length) = $inject;
    Devel::Declare::set_linestr($linestr);
    
    return $previous;
}

#
# skip the sub_name just parsed (is still in $Declarator)
#
sub skip_declarator {
    $Offset += Devel::Declare::toke_move_past_token($Offset);
}

#
# read a valid name if possible
#
sub strip_name {
    skipspace;
    
    if (my $length = Devel::Declare::toke_scan_word($Offset, 1)) {
        return inject('',$length);
    }
    return;
}

#
# read a prototype-like definition (looks like '(...)')
#
sub strip_proto {
    if (next_char eq '(') {
        my $length = Devel::Declare::toke_scan_str($Offset);
        my $proto = Devel::Declare::get_lex_stuff();
        Devel::Declare::clear_lex_stuff();
        inject('', $length);
        return $proto;
    }
    return;
}

#
# inject something at top of a '{ ...}' block
# returns: boolean depending on success
#
sub inject_if_block {
    my $inject = shift;
    
    if (next_char eq '{') {
        inject($inject,0,1);
        return 1;
    }
    return 0;
}

# CURRENTLY NOT NEEDED
# #
# # inject something before a '{ ...}' block
# # returns: boolean depending on success
# #
# sub inject_before_block {
#     my $inject = shift;
#     
#     if (next_char eq '{') {
#         inject($inject);
#         return 1;
#     }
#     
#     return 0;
# }

# CURRENTLY NOT NEEDED
# #
# # put modified sub into requested package
# #
# sub shadow {
#     my $package = Devel::Declare::get_curstash_name;
#     my $code = shift;
#     warn "putting $Declarator into $package...";
#     Devel::Declare::shadow_sub("$package\::$Declarator", $code);
# }

# CURRENTLY NOT NEEDED
# #
# # inject something after scope as soon as '}' is reached
# #
# sub inject_scope {
#     on_scope_end {
#         my $linestr = Devel::Declare::get_linestr;
#         my $offset = Devel::Declare::get_linestr_offset;
#         
#         substr($linestr, $offset, 0) = ';';
#         Devel::Declare::set_linestr($linestr);
#     };
# }

#
# helper: check if a declarator is in a hash key
#
sub declarator_is_hash_key {
    my $offset_before = $Offset;
    skip_declarator;
    
    # This means that current declarator is in a hash key.
    # Don't shadow sub in this case
    return ($Offset == $offset_before);
}

#
# parse: id?   ('.' class)*   ( '(' .* ')' )?
#
sub parse_declaration {
    # collect ID, class and (...) staff here...
    # for later injection into top of block
    my $extras = '';
    
    # check for an indentifier (ID)
    if (next_char =~ m{\A[a-zA-Z0-9_]}xms) {
        # looks like an ID
        my $name = strip_name;
        $extras .= ($extras ? ' ' : '') . "id '$name';";
    }
    
    # check for '.class' as often as possible
    my @class;
    while (next_char eq '.') {
        # found '.' -- eliminate it and read name
        inject('',1);
        push @class, strip_name;
    }
    if (scalar(@class)) {
        $extras .= ($extras ? ' ' : '') . "class '" . join(' ', @class) . "';";
    }
    
    #
    # see if we have (...) stuff
    #
    my $proto = strip_proto;
    if ($proto) {
        ### FIXME: multiline (...) things will otherwise fail
        $proto =~ s{,\s*[\r\n]\s*(\w+)}{, $1}xmsg;
        $extras .= ($extras ? ' ' : '') . "attr $proto;";
    }
    
    #
    # insert extras into the block
    # in doubt creating a new one...
    #
    if ($extras) {
        inject_if_block(qq{$extras;})
            or inject(qq({$extras;};));
    }
}

####################################### PARSERs
#
# generate a tag-parser
# initiated after compiling a tag subroutine
# parses: tag   id?   ('.' class)*   ( '(' .* ')' )?
# injects some magic into the block following the declaration
#
sub tag_parser {
    return sub {
        local ($Declarator, $Offset) = @_;
        return if (declarator_is_hash_key);
        
        parse_declaration;
    };
}

#
# generate a block-parser
# initiated after compiling 'block'
# parses: 'block'   name   id?   ('.' class)*   ( '(' .* ')' )?
# injects 'sub' instead of 'block'
#
sub block_parser {
    return sub {
        local ($Declarator, $Offset) = @_;
        my $inject_position = $Offset;
        return if (declarator_is_hash_key);
        
        inject('sub', $Offset - $inject_position, $inject_position);
        
        parse_declaration;
    };
}

#
# idea: replace 'template' by 'sub RUN'
# does not work yet...
#
sub template_parser {
    return sub {
        local ($Declarator, $Offset) = @_;
        #my $inject_position = $Offset;
        # return if (declarator_is_hash_key);
        #skip_declarator;
        my $linestr = Devel::Declare::get_linestr;
        warn "Template. Offset=$Offset, source = " . substr($linestr, $Offset, 10);

        inject('; sub RUN', 8);
    }
}
1;
