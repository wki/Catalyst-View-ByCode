package Catalyst::View::ByCode::Declare;
use strict;
use warnings;

use Devel::Declare();
use B::Hooks::EndOfScope;
use Data::Dump 'dump';


###### Thanks #####################################################
#                                                                 #
# Thanks to Kang-min Liu for doing 'Markapl.pm'                   #
# most of the concepts here are 'borrowed' from this great module #
# sorry for copying instead of thinking.                          #
#                                                                 #
###### /Thanks ####################################################


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

#
# inject something at current position
#  - with optional length
#  - plus optional offset
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
# read a prototype-like definition (in '(...)')
#
sub strip_proto {
    if (next_char eq '(') {
        warn "$Declarator: proto found...";
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
        ### CRASHES!!!
        warn "must inject: (($inject))";
        inject($inject,0,1);
        #inject('warn "xx";', 0,1);
        return 1;
    }
    return 0;
}

#
# inject something before a '{ ...}' block
# returns: boolean depending on success
#
sub inject_before_block {
    my $inject = shift;
    
    if (next_char eq '{') {
        inject($inject);
        return 1;
    }
    
    return 0;
}

# #
# # put modified sub into requested package
# #
# sub shadow {
#     my $package = Devel::Declare::get_curstash_name;
#     my $code = shift;
#     warn "putting $Declarator into $package...";
#     Devel::Declare::shadow_sub("$package\::$Declarator", $code);
# }

#
# inject something after scope as soon as '}' is reached
#
sub inject_scope {
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        my $offset = Devel::Declare::get_linestr_offset;
        
        warn "inject_scope: offset=$offset";
        substr($linestr, $offset, 0) = ';';
        Devel::Declare::set_linestr($linestr);
    };
}

#
# generate a tag-parser for a given tag
#
sub tag_parser_for {
    my ($tag) = @_;
    
    return sub {
        local ($Declarator, $Offset) = @_;
        
        # collect ID and class staff here...
        my %extras = ();
        
        warn "Declarator=$Declarator, Offset=$Offset";
        # warn "linestr=" . Devel::Declare::get_linestr;
        
        my $offset_before = $Offset;
        skip_declarator;
        
        # This means that current declarator is in a hash key.
        # Don't shadow sub in this case
        return if $Offset == $offset_before;
        
        if ($Declarator eq 'img') {
            warn "IMG IMG IMG next char: " . next_char . 'diff = ' . ($Offset - $offset_before);
        }
        
        # check for an indentifier (ID)
        if (next_char =~ m{\A[a-zA-Z0-9_]}xms) {
            # looks like an ID
            $extras{id} = strip_name;
        }
        
        # check for '.'
        while (next_char eq '.') {
            # found '.' -- eliminate it and read name
            inject('',1);
            push @{$extras{class}}, strip_name;
        }
        
        #
        # see if we have (...) stuff
        #
        my $proto = strip_proto;
        if ($proto) {
            %extras = (%extras, eval "($proto)");
        }
        
        my $extra_text = scalar(keys(%extras)) ? dump(%extras) : '';
        warn "$Declarator proto: $proto extras: $extra_text";
        
        #
        # add a semicolon after the next scope
        #   - if we found a { ... } block
        #
        # or after the last token we found
        #   - if we did not find a { ... } block
        #
        if ($extra_text) {
            inject_if_block(qq{attr $extra_text;})
                or inject(qq({attr $extra_text;};));
        }
        inject_if_block("BEGIN { Catalyst::View::ByCode::Declare::inject_scope };")
            or inject(';');
        
        #
        # no shadowing needed - sub already intact
        #
    };
}

1;
