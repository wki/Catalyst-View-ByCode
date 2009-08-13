package Catalyst::View::ByCode::Markup::Tag;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use HTML::Tagset;

extends 'Catalyst::View::ByCode::Markup::Structured';

subtype 'HashRefOfRef' => as 'HashRef[Ref]';
subtype 'HashRefOfIdent' => as 'HashRef[Str]'
    => where { !grep { !m{\A[a-zA-Z][a-zA-Z0-9-_]*\z}xms } keys %$_ };
coerce 'HashRefOfIdent'
    => from 'HashRefOfRef'
    => via { { map { "$_ " } %{$_} } };
    
has tag => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has attr => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    # isa => 'HashRef[Str]',
    isa => 'HashRefOfIdent',
    lazy => 1,
    default => sub { {} },
    coerce => 1,
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
override as_text => sub {
    my $self = shift;
    my $indent_level = shift || 0;
    my $need_break = shift;
    
    my $dummy; $need_break ||= \$dummy;
    
    # just content if no tag name given
    return super() if (!$self->tag);
    
    # wrap content into a tag
    my $result = '';
    if ($break_before{$self->tag} && $$need_break) {
        $result .= "\n" . (' ' x ($INDENT_STEP * $indent_level));
    }
    $result .= qq{<${\$self->tag}};
    $result .= qq{ $_="${\$self->_html_escape($self->attr->{$_})}"}
        for sort keys(%{$self->attr});
    
    # distinguish between empty tags and content-containing ones...
    if (!exists($HTML::Tagset::emptyElement{$self->tag})) {
        # content containg tag
        $result .= '>';
        if ($break_within{$self->tag}) {
            $result .= "\n" . (' ' x ($INDENT_STEP * ($indent_level+1)));
            $$need_break = 0;
        }
        $result .= super();
        if ($break_within{$self->tag}) {
            $result .= "\n" . (' ' x ($INDENT_STEP * $indent_level));
        }
        $result .= qq{</${\$self->tag}>};
    } else {
        $result .= ' />';
    }
    
    ### break_after -- should indent less sometimes, we don't know...
    $$need_break = 1 if ($break_after{$self->tag});
    
    return $result;
};

no Moose;
1;
