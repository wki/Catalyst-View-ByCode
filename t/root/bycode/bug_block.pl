#
# before fixing this block fails getting attr() values
#
block block1 => sub {
    my $id = attr('id');
    my $class = attr('class');
    my $xxx = attr('xxx');
    my $unknown = attr('unknown');
    
    my $is_ok = 0;
    
    if (defined($id) && !ref($id) && $id eq 'stupid' &&
        defined($class) && !ref($class) && $class eq 'bad' &&
        defined($xxx) && !ref($xxx) && $xxx == 42 &&
        !defined($unknown)) {
        # everything as we expect...
        $is_ok = 1;
    }
    
    div block1 {
        block_content;
        "OK: $is_ok";
    };
};

block 'block2', sub {
    my $id = attr('id');
    my $class = attr('class');
    my $xxx = attr('xxx');
    my $unknown = attr('unknown');
    
    my $is_ok = 0;
    
    if (defined($id) && !ref($id) && $id eq 'stupid' &&
        defined($class) && !ref($class) && $class eq 'bad' &&
        defined($xxx) && !ref($xxx) && $xxx == 42 &&
        !defined($unknown)) {
        # everything as we expect...
        $is_ok = 1;
    }
    
    div block2 {
        block_content;
        "OK: $is_ok";
    };
};


#
# before and after fixing this block is able to get attr() values
#
block block3 {
    my $id = attr('id');
    my $class = attr('class');
    my $xxx = attr('xxx');
    my $unknown = attr('unknown');
    
    my $is_ok = 0;
    
    if (defined($id) && !ref($id) && $id eq 'stupid' &&
        defined($class) && !ref($class) && $class eq 'bad' &&
        defined($xxx) && !ref($xxx) && $xxx == 42 &&
        !defined($unknown)) {
        # everything as we expect...
        $is_ok = 1;
    }
    
    div block3 {
        block_content;
        "OK: $is_ok";
    };
};

template {
    b { 'block1:' };
    block1 stupid.bad(xxx => 42) { '-1-' };
    
    b { 'block2:' };
    block2 stupid.bad(xxx => 42) { '-2-' };
    
    b { 'block3:' };
    block3 stupid.bad(xxx => 42) { '-3-' };
    
    b { 'after blocks' };
};
