package Catalyst::View::ByCode::Markup;

use strict;
use warnings;

use Catalyst::View::ByCode::Util;
use HTML::Tagset;
use List::Util qw(max);

#
# define break positions
#
our %break_after =
    map {$_=>1}
    (keys(%HTML::Tagset::canTighten), keys(%HTML::Tagset::isHeadElement));

our %break_before =
    map {$_=>1}
    (keys(%HTML::Tagset::canTighten), keys(%HTML::Tagset::isHeadElement));

our %break_within =
    map {$_=>1}
    grep {!m{(?:label|option|textarea|h\d|title)}xms} # well, some exceptions needed
    (keys(%HTML::Tagset::canTighten));

#
# indentation
#
our $INDENT_STEP = 2;

#
# construct a new markup
#
sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->{tag}           = '';    # name of tag
    $self->{attr}          = {};    # attributes
    $self->{data}          = undef; # <form> tags fill their elements with it
    $self->{content}       = [];    # content of this tag
    $self->{code}          = undef; # maybe a code reference to execute
    $self->{callback}      = {};    # just to be compatible with H::B...
    $self->{last_element}  = $self; # "pointer" to last open structure
    $self->{open_elements} = [];    # stack with open elements
    $self->{global_data}   = {};    # data for a tag having id='ID'
    $self->{load}          = {};    # reference to 'load' tags

    return $self;
}

#
# determine a trail
#
sub get_trail {
    my $self = shift;
    my $selector = shift;
    $selector = undef if (ref($selector) || $selector eq '');

    #
    # first: get parts of current trail-path
    #
    my @trail_parts = map { $_->{attr}->{-trail} }
                      grep { exists($_->{attr}->{-trail}) }
                      ($self, @{$self->{open_elements}}, $self->{last_element});

    #
    # filter it
    #
    if (!defined($selector)) {
        # do nothing
    } elsif ($selector =~ s{\A (<+)}{}xms) {
        #
        # '<' :: remove from end
        #
        splice @trail_parts, -max(length($1), scalar(@trail_parts));
    } elsif ($selector =~ s{\A (>+)}{}xms) {
        #
        # '>' :: scan from start
        #
        splice @trail_parts, max(length($1), scalar(@trail_parts));
    } elsif ($selector =~ s{\A [.] ([a-zA-Z]+) _*}{}xms) {
        #
        # '.' or '_' search for a named thing
        #
        my $search_for = $1;
        my $found = -1;

        for my $i (0 .. scalar(@trail_parts)-1) {
            if ($trail_parts[$i] eq $search_for) {
                $found = $i;
            }
        }
        splice(@trail_parts, $found+1);
    }

    push @trail_parts, $selector if (defined($selector));

    return join('_', @trail_parts);
}

#
# set starting trail
#
sub set_trail {
    my $self = shift;
    my $trail = shift;

    $self->{attr}->{-trail} = $trail;
}

#
# set data (a hashref) for a tag having ID
#
sub set_data {
    my $self = shift;
    my $id   = shift;
    my $data = shift;

    die 'invalid params' if (!$id || ref($data) ne 'HASH');

    $self->{global_data}->{$id} = $data;
}

#
# open a new tag
#
sub open_tag {
    my $self = shift;
    my $tag = shift;

    my $element = {
                    tag     => $tag,
                    attr    => {},
                    data    => undef,
                    content => [@_],
                  };
    push @{$self->{open_elements}}, $self->{last_element};
    push @{$self->{last_element}->{content}}, $element;
    $self->{last_element} = $element;
}

#
# close last opened tag
#
sub close_tag {
    my $self = shift;

    return if (!scalar(@{$self->{open_elements}}));

    # fake 'id' if '-trail' attr is given
    $self->{last_element}->{attr}->{id} = $self->get_trail()
        if (exists($self->{last_element}->{attr}->{-trail}));

    $self->{last_element} = pop(@{$self->{open_elements}});
}

#
# add a complete tag
#   add_tag('tagname');
#   add_tag('tagname', {attrs});
#   add_tag('tagname', {attrs}, 'content', ...);
#   add_tag('tagname', 'content');
#
sub add_tag {
    my $self     = shift;
    my $tag_name = shift;

    my $attr = {};
    if (scalar(@_) && ref($_[0]) eq 'HASH') {
        $attr = shift;
    }

    $self->open_tag($tag_name, @_);
    $self->attr($attr);
    $self->close_tag();
}

#
# add some content
#
sub add_content {
    my $self = shift;

    # a handy definition
    my $lc = $self->{last_element}->{callback};
    
    #
    # add content
    #
    foreach my $thing (grep { defined($_) } @_) {
        #
        # check if parent requested a 'child' callback
        #
        #next if (scalar(@{$self->{open_elements}}) && 
        #         $self->_handle_callback(child => $thing, $self->{open_elements}->[-1]));
        #next if (ref($self->{last_element}->{callback}->{child}) eq 'CODE'
        #         && $self->{last_element}->{callback}->{child}->($thing, $self->{last_element}));
        next if (($lc->{child} || \&_nothing)->($thing, $self->{last_element}));
        next if (($lc->{descendant} || \&_nothing)->($thing, $self->{last_element}));
                 
        ### TODO: find an elegant way to fire 'descendant' callback efficiently

        #
        # add to content of latest open tag or apply-block
        #
        if (ref($thing) eq 'HASH' &&
            ref($thing->{code}) eq 'CODE') {
            #
            # Just encountered a tag (or apply-block)
            # code must get executed in order for tag's
            # content to get added
            #
            my $tc = $thing->{callback};

            #
            # build a combined 'descendant' callback
            #
            if ($tc->{descendant} && $lc->{descendant}) {
                $tc->{descendant} = sub {
                    return $tc->{descendant}->(@_) || $lc->{descendant}->(@_);
                };
            } else {
                $tc->{descendant} ||= $lc->{descendant};
            }

            #if (!$self->_handle_callback(before => $thing)) {
            unless ( ($tc->{before} || \&_nothing)->($thing, $self->{last_element}) ) {
                #
                # add thing as last element's content
                #
                push @{$self->{last_element}->{content}}, $thing;

                #
                # simulate a 'tag open' operation
                #
                push @{$self->{open_elements}}, $self->{last_element};
                $self->{last_element} = $thing;
                #if (!$self->_handle_callback(top => $thing, $self->{open_elements}->[-1])) {
                unless ( ($tc->{bottom} || \&_nothing)->($thing, $self->{open_elements}->[-1]) ) {
                    #
                    # execute code inside the tag or block
                    #
                    my $result = $thing->{code}->($thing);
                    $self->add_content($result) if (defined($result));
                }

                #
                # close again
                #
                # $self->_handle_callback(bottom => $thing, $self->{open_elements}->[-1]);
                ($tc->{bottom} || \&_nothing)->($thing, $self->{open_elements}->[-1]);
                $self->close_tag();
            }
            # $self->_handle_callback(after => $thing)
            ($tc->{after} || \&_nothing)->($thing, $self->{last_element});
        } else {
            #
            # something else - simply add
            #
            push @{$self->{last_element}->{content}}, $thing;
        }
    }
}

#
# add comment
#
sub add_comment {
    my $self = shift;
    $self->add_tag('', '<!-- ', @_, ' -->');
}

#
# add cdata
#
sub add_cdata {
    my $self = shift;
    $self->add_tag('', '<![CDATA[', @_, ']]>');
}

#
# add raw unescaped data
#
sub add_raw {
    my $self = shift;
    $self->add_tag('-', @_);
}

#
# set attributes
#
sub attr {
    my $self = shift;
    my $attr = shift;

    return if (ref($attr) ne 'HASH');

    $self->{last_element}->{attr}->{$_} = $attr->{$_}
            for keys %{$attr};
}

#
# set some data
#
sub data {
    my $self = shift;
    my $data = shift;

    $self->{last_element}->{data}->{$_} = $data->{$_}
        for keys %{$data};
}

#
# return entire markup as (xml) text
#
sub as_text {
    my $self = shift;

    $self->{_text}       = '';    # cumulative text
    $self->{_indent}     = 0;     # current indentation level
    $self->{_need_break} = 0;     # should we break upon next _append() call?
    $self->{_data}       = undef; # temporarily store data here
    $self->{_seen}       = {};    # mark seen data elements during processing
    $self->{_name_prefix}= '';    # form_name prefix

    $self->_content_as_text($self->{content});

    return $self->{_text};
}

#
# helper: give back an attribute text eventually quoting some chars
#
sub _attr_text {
    my $text      = shift;
    my $hex_chars = shift;

    $text = '' if (!defined($text));

    if ($hex_chars) {
        #
        # nonstandard escaping of some chars for later retrieval
        # $nnnn
        #
        $text =~ s{([\%$hex_chars])}{sprintf('$%04x', ord($1))}exmsg;
    }
    $text =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;

    return $text;
}

#
# helper: produce text for a tag's attribute
#
sub _attr {
    my $attr_name = shift;
    my $attr_data = shift;

    if (!defined($attr_data)) {
        return '';
    } elsif (!ref($attr_data)) {
        #
        # a simple scalar - the most often case - work on it directly
        #
        return _attr_text("$attr_data");
        # this does not improve:
        # $attr_data =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;
        # return $attr_data;
    } elsif (ref($attr_data) eq 'ARRAY') {
        #
        # array -> concatenate things together
        #          onXXX  => nothing between things
        #          others => ' ' between things
        #
        return join( ($attr_name =~ m{\A on}xms) ? '' : ' ',
                     map {_attr($attr_name, $_)}
                     (@{$attr_data}) );
    } elsif (ref($attr_data) eq 'HASH') {
        #
        # hash -> ";" divide key: value pairs
        # with (strange) $nnnn escaping of bad characters
        #
        return join( '; ',
                     map { _attr_text($_,';:$') .
                           ': ' .
                           _attr($attr_name, $attr_data->{$_}, ';:$') }
                     keys %{$attr_data} );
    } elsif (ref($attr_data) eq 'CODE') {
        #
        # follow the code-ref
        #
        return _attr($attr_name, $attr_data->());
    } elsif (ref($attr_data) eq 'SCALAR' || ref($attr_data) eq 'REF') {
        #
        # evaluate a scalar ref or a ref-ref
        #
        return _attr($attr_name, ${$attr_data});
    } else {
        #
        # somesthing strange -- force to become a string
        #
        return _attr_text("$attr_data");
    }
}

#
# helper: do xml escaping
#
sub _xml_escape {
    return _attr_text(shift()); # maybe something else some day...
}

#
# helper: lowlevel text output maybe with break
#
sub _append {
    my $self    = shift;
    my $content = shift;        # current element
    my $break   = shift || 0;   # should break occur?

    if ($break && $self->{_need_break}) {
        $self->{_text} .= "\n" . (' ' x $self->{_indent})
            if ($self->{_text}); # don't break at document start...
        $self->{_need_break} = 0;
    }
    $self->{_text} .= $content;
}

#
# helper: convert a content (recursively) into (xml) text
#
sub _content_as_text {
    my $self      = shift;
    my $element   = shift; # current element
    my $do_escape = shift;

    $do_escape = 1 if (!defined($do_escape));

    if (ref($element) eq 'ARRAY') {
        #
        # collection of something -- just concatenate
        #
        $self->_content_as_text($_, $do_escape)
            for (@{$element});
    } elsif (ref($element) eq 'HASH') {
        #
        # a Tag - do we need some preparation?
        # only if tag-name is defined
        #
        my $saved_prefix = $self->{_name_prefix};

        if (defined($element->{tag})) {
            if (exists($element->{attr}->{-top})) {
                unshift @{$element->{content}}, @{_taglist($element->{attr}->{-top})};
                delete $element->{attr}->{-top};
            }

            if (exists($element->{attr}->{-bottom})) {
                push @{$element->{content}}, @{_taglist($element->{attr}->{-bottom})};
                delete $element->{attr}->{-bottom};
            }

            if (exists($element->{attr}->{-wrap})) {
                my @taglist = reverse @{_taglist($element->{attr}->{-wrap})};
                delete $element->{attr}->{-wrap};
                foreach my $tag (@taglist) {
                    $tag->{content} = [ $element ];
                    $element = $tag;
                }
            }
            if (exists($element->{attr}->{-prefix})) {
                my @tags = _taglist($element->{attr}->{-prefix});
                $self->_tag_as_text({tag => '', content => $_}, $do_escape)
                    for @tags;
            }
        }

        # must stay outside the condition above to make Form::fields work
        if (exists($element->{attr}->{-group})) {
            my $group = $element->{attr}->{-group};
            if (!defined($group) || $group eq '') {
                $self->{_name_prefix} = '';
            } else {
                $self->{_name_prefix} .= ($self->{_name_prefix} ? '.' : '')
                                      .  $element->{attr}->{-group};
            }
        }
        if (exists($element->{attr}->{-index})) {
            $self->{_name_prefix} .= ":$element->{attr}->{-index}";
        }

        $self->_tag_as_text($element, $do_escape);

        $self->{_name_prefix} = $saved_prefix;

        if (defined($element->{tag})) {
            if (exists($element->{attr}->{-append})) {
                my @tags = _taglist($element->{attr}->{-append});
                $self->_tag_as_text({tag => '', content => $_}, $do_escape)
                    for @tags;
            }
        }
    } elsif (ref($element) eq 'CODE') {
        #
        # code-ref
        #
        $self->_append($do_escape ? _xml_escape($element->()) : $element->());
    } elsif (ref($element) eq 'SCALAR' || ref($element) eq 'REF') {
        #
        # scalar-ref or ref-ref - descent once more
        #
        $self->_content_as_text(${$element}, $do_escape);
    } else {
        #
        # constant text
        #
        $self->_append($do_escape ? _xml_escape($element) : $element, 0);
    }
}

#
# helper: generate a tag
#
sub _tag_as_text {
    my $self      = shift;
    my $element   = shift; # current element
    my $do_escape = shift;

    $do_escape = 1 if (!defined($do_escape));

    my $tag = $element->{tag} || '';
    if ($tag eq '-') {
        #
        # raw unescaped output
        #
        $self->_content_as_text($element->{content}, 0);
    } elsif (!$tag) {
        #
        # escaped output
        #
        $self->_content_as_text($element->{content}, $do_escape);
    } else {
        $self->{_need_break} = 1 if (exists($break_before{$tag}));

        #
        # extract some info if present
        #
        my $id = exists($element->{attr}->{id})
            ? $element->{attr}->{id}
            : undef;

        #
        # save and build data (if any)
        #
        my $saved_data   = $self->{_data};

        #
        # extract element's or global data if it makes sense...
        #
        if ($element->{data} &&
            ref($element->{data}) eq 'HASH' &&
            scalar(keys(%{$element->{data}}))) {
            #
            # element's data has more priority than global data
            #
            $self->{_data} = $element->{data};
        } elsif ($id && exists($self->{global_data}->{$id})) {
            #
            # global data has lower priority
            #
            $self->{_data} = $self->{global_data}->{$id};
        }

        #
        # prepare this tag if possible
        #
        if ($self->can("prepare_$tag")) {
            no strict 'refs';
            &{"prepare_$tag"}($self,$element);
            use strict 'refs';
        }

        #
        # construct open tag
        #
        $self->_append(join(' ',
                            # the opening tag
                            "<$tag",

                            # all regular attributes (not starting with '-')
                            ( map { "$_=\"" . _attr($_, $element->{attr}->{$_}) . "\"" }
                              grep { !m{\A -}xms }
                              keys %{$element->{attr}} ),

                            # the '-data' attribute hash
                            ( exists($element->{attr}->{-data}) &&
                              ref($element->{attr}->{-data}) eq 'HASH'
                              ? (map { "data-$_=\"" . _attr("data-$_", $element->{attr}->{-data}->{$_}) . "\"" }
                                 keys %{$element->{attr}->{-data}}
                                )
                              : ()
                              ),
                            ),
                       1);
        if (!exists($HTML::Tagset::emptyElement{$tag})) {
            $self->_append('>');

            #
            # generate tag content
            #
            $self->{_need_break} = 1 if (exists($break_within{$tag}));

            $self->{_indent} += $INDENT_STEP;
            $self->_content_as_text($element->{content}, $do_escape);

            #
            # fixup this tag if possible
            #
            if ($self->can("fixup_$tag")) {
                no strict 'refs';
                &{"fixup_$tag"}($self,$element);
            }

            #
            # close tag
            #
            $self->{_indent} -= $INDENT_STEP;

            $self->{_need_break} = 1 if (exists($break_within{$tag}));
            $self->_append("</$tag>", 1);
        } else {
            # a tag that does not generate content (like br or hr),
            # will never get fixed up. (!)
            $self->_append(' />');
        }

        #
        # restore data (if any)
        #
        $self->{_data}   = $saved_data;

        $self->{_need_break} = 1 if (exists($break_after{$tag}));
    }
}

#
# helper: build a list of element-like {}'s from
#  - 'content'   OBSOLETE, before: 'tagname'
#  - ['tagname', optional {attr}, optional [content] ...]  //  empty tagname|undef => (plain text)
#
sub _taglist {
    my $taglist = shift;

    my @result;
    if (!ref($taglist) && $taglist) {
        #
        # single scalar is content
        #
        push @result, {
            tag     => '',
            attr    => {},
            data    => undef,
            content => [ \$taglist ],
        };

    } elsif (ref($taglist) eq 'ARRAY') {
        #
        # a list of consecutive divs maybe with attrs and content
        #
        my $i = 0;
        while ($i < scalar(@{$taglist})) {
            my $tag = $taglist->[$i++];
            if (!defined($tag) || (!ref($tag) && $tag eq '')) {
                #
                # empty tagname -> test next thing
                #
                if ($i < scalar(@{$taglist}) && !ref($taglist->[$i])) {
                    #
                    # scalar content -> add as content
                    #
                    push @result, {
                        tag     => '',
                        attr    => {},
                        data    => undef,
                        content => [ $taglist->[$i++] ],
                    };
                }
            } elsif (ref($tag) eq 'SCALAR') {
                #
                # scalar ref -> add as content
                #
                push @result, {
                    tag     => undef,
                    attr    => {},
                    data    => undef,
                    content => [ ${$tag} ],
                };
            } elsif (!ref($tag)) {
                #
                # tag name was a scalar - scan attr and content if present
                #
                my $attr = {};
                my $content = [];
                while ($i < scalar(@{$taglist})) {
                    if (ref($taglist->[$i]) eq 'HASH') {
                        $attr = $taglist->[$i++];
                    } elsif (ref($taglist->[$i]) eq 'ARRAY') {
                        $content = _taglist($taglist->[$i++]);
                    } else {
                        last;
                    }
                }
                push @result, {
                    tag     => $tag,
                    attr    => $attr,
                    data    => undef,
                    content => $content,
                };
            } else {
                #
                # something we cannot work with - ignore
                #
                $i++;
            }
        } # while (i < scalar...)
    } else {
        # something very strange - simply ignore
    }

    return \@result;
}

############################## HELPERS
#
# traverse the tree starting at a point finding elements satisfying a function
#
sub _matching (&$) {
    return __matching(@_); # avoid type-checking inside recursion
}

sub __matching {
    my $does_match = shift; # matching function for a single tag
    my $element    = shift;

    my @found = ();
    if (ref($element) eq 'ARRAY') {
        # collection of things
        push @found, __matching($does_match, $_) for @{$element};
    } elsif (ref($element) eq 'HASH') {
        # a tag
        push @found, $element if ($does_match->($element));
        push @found, __matching($does_match, $element->{content});
    }

    return @found;
}

#
# helper: try to get data for a form element if possible
#
sub _extract_data {
    my $self = shift;
    my $name = shift;

    if ($self->{_data}) {
        #
        # we have data - try to find it
        #
        if (ref($self->{_data}) eq 'HASH' &&
            exists($self->{_data}->{$name})) {
            #
            # simple lookup succesful -- return data
            #
            return ($self->{_data}->{$name});
        } elsif ($name =~ m{[.:]}xms) {
            #
            # field name is composed of '.' or ':' separated things
            #
            my $data = $self->{_data};
            while ($name =~ m{\G([.:]?)([^.:]+)}xmsg) {
                my $prefix = $1;
                my $comp = $2;
                if (!$prefix || $prefix eq '.') {
                    # hash (.)
                    return if (ref($data) ne 'HASH' ||
                               !exists($data->{$comp}));
                    $data = $data->{$comp};
                } elsif ($comp =~ m{\A \d+ \z}xms) {
                    # array (:)
                    return if (ref($data) ne 'ARRAY' ||
                               scalar(@{$data}) <= $comp);
                    $data = $data->[$comp];
                } else {
                    # nothing valid - assume data not present
                    return;
                }
            }
            return $data;
        }
    }

    #
    # nothing found -- silently terminate
    #
    return;
}

#
# handle a callback for a tag
#
sub _handle_callback {
    my $self = shift;
    my $callback = shift;
    my $thing = shift;
    my $parent = shift || $self->{last_element};

    # continue if requested callback not present
    return if (ref($thing->{callback}->{$callback}) ne 'CODE');
    
    ### TODO: check callback's type -- handle ARRAY and CODE.
    
    # execute callback and return its result
    return $thing->{callback}->{$callback}->($thing, $parent);
}

#
# simple function that does nothing
#
sub _nothing { return; }

############################## HANDLE SOME HTML ELEMENTS SPECIALLY
#
# prepare and fixup a <form>
#
sub prepare_form {
    my $self = shift;
    my $element = shift;

    $self->{_seen} = {};
}

sub fixup_form {
    my $self = shift;
    my $element = shift;

    #
    # build hidden fields for all unseen data elements, restore data
    #
    if ($self->{_data} && ref($self->{_data}) eq 'HASH') {
        foreach my $name (grep {!exists($self->{_seen}->{$_})}
                          keys(%{$self->{_data}})) {
            $self->{_need_break} = 1;
            my $field_name = $name;
            my $value = $self->{_data}->{$name};
            if (ref($value)) {
                $field_name .= '__yaml';
                $value = encode_64($value);
            }
            $self->_tag_as_text({tag     => 'input',
                                 content => [],
                                 attr    => {type  => 'hidden',
                                             name  => $field_name,
                                             value => $value}});
            $self->{_need_break} = 1;
        }
    }
}

#
# prepare <input> tags
#
sub prepare_input {
    my $self = shift;
    my $element = shift;

    my $name = $element->{attr}->{name} or return;
    my $type = $element->{attr}->{type};

    if ($self->{_name_prefix}) {
        $name = "$self->{_name_prefix}.$name";
        $element->{attr}->{name} = $name;
    }

    my $value = $self->_extract_data($name);
    if (defined($value)) {
        #
        # determine type of input
        #
        if (!defined($type) || !$type) {
            #
            # no type -> assume and set 'text'
            #
            $type = $element->{attr}->{type} = 'text';
        }
        if ($type eq 'checkbox' || $type eq 'radio') {
            #
            # radio or checkbox -- set 'checked' if needed
            #
            if ($element->{attr}->{value} eq $value) {
                $element->{attr}->{checked} = 'checked';
            } else {
                delete $element->{attr}->{checked};
            }
        } else {
            #
            # all other kinds -- just set value
            #
            $element->{attr}->{value} = $value;
        }
    } elsif ($type eq 'submit' && !exists($element->{attr}->{value})) {
        #
        # set a submit button's name if not there
        #
        $element->{attr}->{value} = $element->{attr}->{name};
    }

    #
    # some more magic
    #
    if (!$self->{_seen}->{$name} &&
        ($type eq 'checkbox' || $type eq 'radio')) {
        #
        # add a hidden field to indicate a checkbox/radio existence
        #
        $self->_tag_as_text({tag     => 'input',
                             content => [],
                             attr    => {type  => 'hidden',
                                         name  => "${name}__value",
                                         value => 1}});
    } elsif ($type eq 'hidden' && ref($element->{attr}->{value})) {
        #
        # hidden tag with some structure -> use encode_64
        #
        if ($name !~ m{__yaml \z}xms) {
            $element->{attr}->{name} .= '__yaml';
        }
        $element->{attr}->{value} = encode_64($element->{attr}->{value});
    }

    #
    # mark as used -- trim down name to its base
    # in case of array or hash
    # not the best way but should work most times
    #
    $name =~ s{[.:].*}{}xms;
    $self->{_seen}->{$name}++;
}

#
# prepare <select> tags
#
sub prepare_select {
    my $self = shift;
    my $element = shift;

    my $name = $element->{attr}->{name} or return;

    if ($self->{_name_prefix}) {
        $name = "$self->{_name_prefix}.$name";
        $element->{attr}->{name} = $name;
    }

    if (my ($value) = $self->_extract_data($name)) {
        #
        # modify all <option> tags to set one as 'selected'
        #
        foreach my $option_tag (_matching {$_->{tag} eq 'option'} $element) {
            if (($option_tag->{attr}->{value} || '') eq $value) {
                $option_tag->{attr}->{selected} = 'selected';
            } else {
                delete $option_tag->{attr}->{selected};
            }
            ### TODO: handle multiple select boxes...
        }
        $self->{_seen}->{$name} ++;
    }
}

#
# prepare <textarea> tags
#
sub prepare_textarea {
    my $self = shift;
    my $element = shift;

    my $name = $element->{attr}->{name} or return;

    if ($self->{_name_prefix}) {
        $name = "$self->{_name_prefix}.$name";
        $element->{attr}->{name} = $name;
    }

    if (my ($value) = $self->_extract_data($name)) {
        #
        # simply replace content
        #
        $element->{content} = $value;
        $self->{_seen}->{$name} ++;
    }
}

1;
