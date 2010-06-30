package Catalyst::View::ByCode::Markup::Tag;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use HTML::Tagset;

extends 'Catalyst::View::ByCode::Markup::Structured';

has tag => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has attr => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    provides => {
        exists => 'has_attr',
        keys   => 'attrs',
        get    => 'get_attr',
        set    => 'set_attr',
        delete => 'delete_attr',
    },
);

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

our $INDENT_STEP = 2;

#
# rendering
#
override as_string => sub {
    my $self = shift;
    my $indent_level = shift || 0;
    my $need_break = shift;
    
    # $need_break is a scalar-ref, therefore we need this ugly fallback
    my $dummy; $need_break ||= \$dummy;
    
    # define some shortcuts for faster access
    my $tag  = $self->tag
        # in case we do not have a tag
        or return join('', map {ref($_) ? $_->as_string($indent_level+1, $need_break) : $_} @{$self->content});
    my $attr = $self->attr;
    
    # wrap content into a tag
    my $result = '';
    if ($break_before{$tag} && $$need_break) {
        $result .= "\n" . (' ' x ($INDENT_STEP * $indent_level));
    }
    $result .= "<$tag";
    
    my $k;
    my $v;
    foreach $k (sort keys(%{$attr})) {
        $v = $attr->{$k} // '';
        
        if ($k =~ m{\A(?:disabled|checked|multiple|readonly|selected)\z}oxms) {
            # special handling for magic names that require magic values
            $result .= qq{ $k="$k"} if ($v);
        } elsif ($k =~ m{\A[a-z]+\z}o && !ref($v) && $v !~ m{[\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}]}o) {
            # trivial case - no escaping needed
            no warnings;
            $result .= qq{ $k="$v"};
        } else {
            # escaping and special value handling needed
            if (ref($v)) {
                $v = ref($v) eq 'ARRAY' ? join(' ', @{$v})
                   : ref($v) eq 'HASH'  ? join(';', map { my $k = $_; $k =~ s{([A-Z])|_}{-\l$1}oxmsg; "$k:$v->{$_}"} keys(%{$v}))
                   : "$v";
            }
            $v =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}oexmsg;
            
            no warnings; # perl5.12 warns anyway... strange.
            
            # convert key into unified version. see _key above
            $k =~ s{([A-Z])|_}{-\l$1}oxmsg;
            
            # compose
            $result .= qq{ $k="$v"};
        }
    }
    
    # distinguish between empty tags and content-containing ones...
    if (!exists($HTML::Tagset::emptyElement{$tag})) {
        # content containg tag
        $result .= '>';
        if ($break_within{$tag}) {
            $result .= "\n" . (' ' x ($INDENT_STEP * ($indent_level+1)));
            $$need_break = 0;
        }
        $result .= join('', map {ref($_) ? $_->as_string($indent_level+1, $need_break) : $_} @{$self->content});
        if ($break_within{$tag}) {
            $result .= "\n" . (' ' x ($INDENT_STEP * $indent_level));
        }
        $result .= "</$tag>";
    } else {
        $result .= ' />';
    }
    
    # just remember break_after as it should indent less sometimes, 
    # we cannot decide this here and now
    $$need_break = 1 if ($break_after{$tag});
    
    return $result;
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
