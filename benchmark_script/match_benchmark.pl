#!/usr/bin/perl
use strict;
use warnings;
use Benchmark ':all';


sub smart {
    my $text = 'selected';
    $text ~~ ~[ qw(disabled|checked|multiple|readonly|selected) ]
      ? 1
      : 0
}

sub regex {
    my $text = 'selected';
    $text =~ m{\A(?:disabled|checked|multiple|readonly|selected)\z}oxms
      ? 1
      : 0
}

sub seq {
    my $text = 'selected';
    $text eq 'disabled' || 
    $text eq 'checked' || 
    $text eq 'multiple' || 
    $text eq 'readonly' || 
    $text eq 'selected'
      ? 1
      : 0
}

timethese(1_000_000, {
    smart => \&smart,
    regex => \&regex,
    seq   => \&seq,
});

