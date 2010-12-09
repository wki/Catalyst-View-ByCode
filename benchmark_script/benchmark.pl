#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Catalyst::View::ByCode::Renderer ':markup';
use Benchmark ':all';

{
    package ByCodeTemplate;
    use Catalyst::View::ByCode::Renderer ':default';
    
    # define a template
    sub exec {
        table {
            tbody {
                for my $row (1..1000) {
                    trow {
                        class '+even' if ($row %2);
                        
                        for my $col (1..10) {
                            tcol {
                                class '+firstcol' if ($col == 1);
                                class '+lastcol'  if ($col == 10);
                                
                                "$row:$col"
                            };
                        }
                        
                        tcol {
                            join('', (0 .. 9));
                        };
                        
                        tcol {
                            $row % 2 ? 'odd' : 'even';
                        };
                    };
                }
            };
        };
    }
}

{
    package TTTemplate;
    use Template;
    
    sub exec {
        my $output = '';
        my $code = q{
        <table>
            <tbody>
                [% FOREACH row IN [1..1000] %]
                <tr[% IF row % 2 %] class="even"[% END %]>
                    [% FOREACH col IN [1..10] %]
                    <td[% IF col == 1 %] class="firstcol"[% ELSIF col == 10 %] class="lastcol"[% END %]>[% row | html %]:[% col | html %]</td>
                    [% END %]
                    <td>
                        [% FOR i IN [0..9] %][% i | html %][% END %]
                    </td>
                    <td>
                        [% IF row % 2 %]odd[% ELSE %]even[% END %]
                    </td>
                </tr>
                [% END %]
            </tbody>
        </table>
        };
        
        my $template = Template->new({INTERPOLATE => 1});
        $template->process(\$code, {}, \$output)
            or die $template->error;
        return $output;
    }
}

# print TTTemplate::exec(); exit;

# init_markup(); ByCodeTemplate::exec(); print get_markup(); exit;

#
# run the simple benchmark
#
cmpthese timethese 100, {
    bycode => sub { init_markup(); ByCodeTemplate::exec(); },
    tt     => sub { TTTemplate::exec(); },
};
