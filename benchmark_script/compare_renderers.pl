#!/usr/bin/perl
#!/usr/local/bin/perl5.12.0
use strict;
use warnings;
use lib '/Users/wolfgang/proj/Catalyst-View-ByCode/lib';
use Benchmark qw(:all);
use IO::String;
use YAML;


do { my $x = "<sdf<<<<"; $x =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf("&#%d;", ord($1))}oexmsg; } for (1 .. 100_000);
exit;


print "Perl $]\n\n";

my @markup = (
    'hello', 'world',
    [ 'h1', {attr => 'value'}, 'content 1', 'content 2' ],
    [ undef, {}, 'some', 'content', 'maybe', 'of', 'interest' ],
    'bye', 'world',
);


{
    package tester;
    our @m;
    our @top = ( \@m ); # open tags
    
    {
        no strict 'refs';
        tie *{'tester::OUT'}, 'tester';
    }
    
    sub TIEHANDLE { bless {}, shift() }
    sub PRINT { push @{$top[-1]}, @_[1..$#_]; return; }
    
    sub h1(;&@) {
        #push @{$top[-1]}, [ 'h1', { @_[1 .. $#_] } ];
        push @{$top[-1]}, [ (caller(0))[3], { @_[1 .. $#_] } ];
        
        if ($_[0]) {
            push @top, $top[-1]->[-1];
            push @{$top[-1]}, $_[0]->() // ();
            pop @top;
        }
        return;
    }
    
    sub some_block {}
    
    sub tester {
        # warn "tester running";
        print OUT 'hello';
        print OUT 'world';
        h1 {
            print OUT 'content 1';
            print OUT 'content 2';
            # h1 { 'adsf' };
        } (attr => 'value');
        some_block;
        print OUT 'bye';
        print OUT 'world';
        
        return;
    }
}

{
    package dummy;
    
    {
        no strict 'refs';
        tie *{'dummy::OUT'}, 'dummy';
    }
    
    sub TIEHANDLE { bless {}, shift() }
    sub PRINT { return; }
    
    sub h1(&;@) { my $x = 1; }
    sub some_block { my $y = 1; }
    
    sub dummy {
        print OUT 'hello';
        print OUT 'world';
        h1 {
            print OUT 'content 1';
            print OUT 'content 2';
        } (attr => 'value');
        some_block;
        print OUT 'bye';
        print OUT 'world';
        
        return;
    }
}

{
    package view_bycode;
    use Catalyst::View::ByCode::Renderer ':default';
    
    block some_block {
       print OUT 'some';
       print OUT 'content';
       print OUT 'maybe';
       print OUT 'of';
       print OUT 'interest';
    };
    
    template {
        print OUT 'hello';
        print OUT 'world';
        h1(attr => 'value') {
            print OUT 'content 1';
            print OUT 'content 2';
        };
        some_block;
        print OUT 'bye';
        print OUT 'world';
    };
    
    sub render_bycode {
        # Catalyst::View::ByCode::Renderer::clear_markup();
        Catalyst::View::ByCode::Renderer::init_markup();
        RUN();
    }
}

{
    package view_bycode_fast;
    use Catalyst::View::ByCode::FastRenderer ':default';
    
    block some_block {
       print OUT 'some';
       print OUT 'content';
       print OUT 'maybe';
       print OUT 'of';
       print OUT 'interest';
    };
    
    template {
        print OUT 'hello';
        print OUT 'world';
        h1(attr => 'value') {
            print OUT 'content 1';
            br;
            input(disabled => 1, style => {display => 'none'}) { 'asdf' };
            print OUT 'content 2';
        };
        some_block;
        print OUT 'bye';
        print OUT 'world';
    };
    
    sub render_bycode {
        # Catalyst::View::ByCode::FastRenderer::clear_markup();
        Catalyst::View::ByCode::FastRenderer::init_markup();
        RUN();
    }
}

# 1st try -- only localize what must get done, fastest
sub render1 {
    join('',
         map {
             ref($_) eq 'ARRAY'
               ? do {
                   my $attr = $_->[1];
                   $_->[0]
                     ? "<$_->[0]" .
                       join(' ', map {qq{ $_="$attr->{$_}"}} keys(%{$attr})) .
                       '>' . 
                       render1(@{$_}[2 .. $#$_]) .
                       "</$_->[0]>"
                     : render1(@{$_}[2 .. $#$_])
                 }
               : $_
         } @_);
}

# 2nd try -- localize tag + attr, almost as fast as #1
sub render2 {
    join('',
         map {
             ref($_) eq 'ARRAY'
               ? do {
                   # my ($tag, $attr, @contents) = @{$_};
                   my $tag  = $_->[0];
                   my $attr = $_->[1];
                   $tag 
                     ? "<$tag" .
                       join(' ', map {qq{ $_="$attr->{$_}"}} keys(%{$attr})) .
                       '>' . 
                       render2(@{$_}[2 .. $#$_]) .
                       "</$tag>"
                     : render2(@{$_}[2 .. $#$_])
                 }
               : $_
         } @_);
}

# 3rd try -- localize tag + attr + @content, slower than #2
sub render3 {
    join('',
         map {
             ref($_) eq 'ARRAY'
               ? do {
                   my ($tag, $attr, @contents) = @{$_};
                   $tag 
                     ? "<$tag" .
                       join(' ', map {qq{ $_="$attr->{$_}"}} keys(%{$attr})) .
                       '>' . 
                       render3(@{$_}[2 .. $#contents]) .
                       "</$tag>"
                     : render3(@{$_}[2 .. $#contents])
                 }
               : $_
         } @_);
}

# @tester::m = ();
# @tester::top = ( \@tester::m );
# tester::tester();
# print Dump(\@tester::m);exit;
# print render1(@tester::m); exit;

# generate markup
# view_bycode::render_bycode();

#view_bycode_fast::render_bycode();
#print 'Markup: ', Catalyst::View::ByCode::FastRenderer::get_markup(), "\n"; exit;

my $results = timethese( 10_000, {
    # reference for calling all those subs
    dummy_subs        => sub { dummy::dummy() },
    
    # an alternative to render code
    tester            => sub { @tester::m = (); @tester::top = ( \@tester::m ); tester::tester() },
    
    # the FASTl ByCode
    fast_create     => sub { view_bycode_fast::render_bycode() },
    fast_get        => sub { Catalyst::View::ByCode::FastRenderer::get_markup() },
    
    # the real ByCode
    markup_create     => sub { view_bycode::render_bycode() },
    markup_get        => sub { Catalyst::View::ByCode::Renderer::get_markup() },
    
    # retrieval from structure
    render_no_local   => sub { render1(@markup) },
    render_2_local    => sub { render2(@markup) },
    render_all_local  => sub { render3(@markup) },
});

cmpthese($results);

__END__
print render(@markup), "\n";

print Dump(\@markup);