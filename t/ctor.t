#!/usr/bin/perl

# $Id: ctor.t 2872 2006-05-28 20:02:16Z david $

##############################################################################
# Set up the tests.
##############################################################################

use strict;
use Test::More tests => 55;

##############################################################################
# Create a simple class.
##############################################################################

package Class::Meta::TestPerson;
use strict;

# Make sure we can load Class::Meta.
BEGIN { main::use_ok( 'Class::Meta' ) }

BEGIN {
    # Import Test::More functions into this package.
    Test::More->import;

    # Create a new Class::Meta object.
    ok( my $c = Class::Meta->new(package => __PACKAGE__,
                                 key     => 'person'),
        "Create CM object" );
    isa_ok($c, 'Class::Meta');

    # Create a constructor.
    sub inst { bless {} }
    ok( my $ctor = $c->add_constructor( name   => 'inst',
                                        desc   => 'The inst constructor',
                                        label  => 'inst Constructor',
                                        create => 0,
                                        view   => Class::Meta::PUBLIC ),
        "Create 'inst' ctor");
    isa_ok($ctor, 'Class::Meta::Constructor');

    # Test its accessors.
    is( $ctor->name, "inst", "Check inst name" );
    is( $ctor->desc, "The inst constructor", "Check inst desc" );
    is( $ctor->label, "inst Constructor", "Check inst label" );
    ok( $ctor->view == Class::Meta::PUBLIC, "Check inst view" );
    isa_ok( $ctor->call(__PACKAGE__), __PACKAGE__);

    # Okay, now test to make sure that an attempt to create a constructor
    # directly fails.
    eval { my $ctor = Class::Meta::Constructor->new };
    ok( my $err = $@, "Get constructor construction exception");
    like( $err, qr/Package 'Class::Meta::TestPerson' cannot create/,
        "Caught proper exception");

    # Now try it without a name.
    eval{ $c->add_constructor() };
    ok( $err = $@, "Caught no name exception");
    like( $err, qr/Parameter 'name' is required in call to new/,
        "Caught proper no name exception");

    # Try a duplicately-named constructor.
    eval{ $c->add_constructor(name => 'inst') };
    ok( $err = $@, "Caught dupe name exception");
    like( $err, qr/Method 'inst' already exists in class/,
        "Caught proper dupe name exception");

    # Try a couple of bogus visibilities.
    eval { $c->add_constructor( name => 'new_ctor',
                                view  => 25) };
    ok( $err = $@, "Caught bogus view exception");
    like( $err, qr/Not a valid view parameter: '25'/,
        "Caught proper bogus view exception");
    eval { $c->add_constructor( name => 'new_ctor',
                                view  => 10) };
    ok( $err = $@, "Caught another bogus view exception");
    like( $err, qr/Not a valid view parameter: '10'/,
        "Caught another proper bogus view exception");

    # Try a bogus caller.
    eval { $c->add_method( name => 'new_inst',
                         caller => 'foo' ) };
    ok( $err = $@, "Caught bogus caller exception");
    like( $err, qr/Parameter caller must be a code reference/,
        "Caught proper bogus caller exception");

    # Now test all of the defaults.
    sub new_ctor { 22 }
    ok( $ctor = $c->add_constructor( name   => 'new_ctor',
                                     create => 0 ), "Create 'new_ctor'" );
    isa_ok($ctor, 'Class::Meta::Constructor');

    # Test its accessors.
    is( $ctor->name, "new_ctor", "Check new_ctor name" );
    ok( ! defined $ctor->desc, "Check new_ctor desc" );
    ok( ! defined $ctor->label, "Check new_ctor label" );
    ok( $ctor->view == Class::Meta::PUBLIC, "Check new_ctor view" );
    is ($ctor->call(__PACKAGE__), '22',
        'Call the new_ctor constructor indirectly' );
}

# Now try subclassing Class::Meta.

package Class::Meta::SubClass;
use base 'Class::Meta';
sub add_constructor {
    Class::Meta::Constructor->new( shift->SUPER::class, @_);
}

package Class::Meta::AnotherTest;
use strict;

BEGIN {
    # Import Test::More functions into this package.
    Test::More->import;

    # Create a new Class::Meta object.
    ok( my $c = Class::Meta::SubClass->new
        (another => __PACKAGE__), "Create subclassed CM object" );
    isa_ok($c, 'Class::Meta');
    isa_ok($c, 'Class::Meta::SubClass');

    sub foo_ctor { bless {} }
    ok( my $ctor = $c->add_constructor( name => 'foo_ctor',
                                        create => 0 ),
        'Create subclassed foo_ctor' );

    isa_ok($ctor, 'Class::Meta::Constructor');

    # Test its accessors.
    is( $ctor->name, "foo_ctor", "Check new foo_ctor name" );
    ok( ! defined $ctor->desc, "Check new foo_ctor desc" );
    ok( ! defined $ctor->label, "Check new foo_ctor label" );
    ok( $ctor->view == Class::Meta::PUBLIC, "Check new foo_ctor view" );
    isa_ok($ctor->call(__PACKAGE__), __PACKAGE__);
}

##############################################################################
# Now try subclassing Class::Meta::Constructor.
package Class::Meta::Constructor::Sub;
use base 'Class::Meta::Constructor';

# Make sure we can override new and build.
sub new { shift->SUPER::new(@_) }
sub build { shift->SUPER::build(@_) }

sub foo { shift->{foo} }

package main;
ok( my $cm = Class::Meta->new(
    constructor_class => 'Class::Meta::Constructor::Sub'
), "Create Class" );
ok( my $ctor = $cm->add_constructor(name => 'foo', foo => 'bar'),
    "Add foo constructor" );
isa_ok($ctor, 'Class::Meta::Constructor::Sub');
isa_ok($ctor, 'Class::Meta::Constructor');
is( $ctor->name, 'foo', "Check an attibute");
is( $ctor->foo, 'bar', "Check added attibute");

##############################################################################
# Now try mixing the setting of attributes.
package Try::Mixed::Constructor;
use Class::Meta::Types::Perl;
BEGIN { Test::More->import }

ok $cm = Class::Meta->new, 'Create new Class::Meta object';
ok $cm->add_constructor(name => 'new'), 'Add a constructor';
# Now write our own constructor.
ok(
    $ctor = $cm->add_constructor(
        name => 'implicit',
        code => sub { ok 'Implicit constructor called' },
    ), 'Implicitly write constructor'
);

ok $cm->add_attribute(
    name => 'foo',
    type => 'scalar',
), 'Add "foo" attribute';

ok $cm->add_attribute(
    name   => 'bar',
    type   => 'scalar',
    create => Class::Meta::NONE,
), 'Add "bar" attribute';

sub bar {
    my $self = shift;
    return $self->{bar} unless @_;
    $self->foo(shift);
    $self->{bar} = 'set';
}

ok $cm->build, 'Build the new class';

ok my $try = Try::Mixed::Constructor->new(bar => 'hey'),
    'Construct an instance of the new class';
is $try->bar, 'set', '"bar" should be "set"';
is $try->foo, 'hey', '"foo" should be "hey"';

# Call implicit constructor and its test.
Try::Mixed::Constructor->implicit;
