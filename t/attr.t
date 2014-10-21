#!/usr/bin/perl

# $Id: attr.t 682 2004-09-28 05:59:10Z david $

##############################################################################
# Set up the tests.
##############################################################################

use strict;
use Test::More tests => 44;

##############################################################################
# Create a simple class.
##############################################################################

package Class::Meta::TestPerson;
use strict;

# Make sure we can load Class::Meta.
BEGIN {
    main::use_ok( 'Class::Meta' );
    main::use_ok( 'Class::Meta::Types::String' );
}

BEGIN {
    # Import Test::More functions into this package.
    Test::More->import;

    # Create a new Class::Meta object.
    ok( my $c = Class::Meta->new(key => 'person'),
        "Create CM object" );
    isa_ok($c, 'Class::Meta');

    # Create an attribute.
    sub inst { bless {} }
    ok( my $attr = $c->add_attribute( name => 'inst',
                                      type => 'string',
                                      desc    => 'The inst attribute',
                                      label   => 'inst Attribute',
                                      view     => Class::Meta::PUBLIC ),
        "Create 'inst' attr");
    isa_ok($attr, 'Class::Meta::Attribute');

    # Test its accessors.
    is( $attr->name, "inst", "Check inst name" );
    is( $attr->desc, "The inst attribute", "Check inst desc" );
    is( $attr->label, "inst Attribute", "Check inst label" );
    is( $attr->type, "string", "Check inst type" );
    ok( $attr->view == Class::Meta::PUBLIC, "Check inst view" );

    # Okay, now test to make sure that an attempt to create a attribute
    # directly fails.
    eval { my $attr = Class::Meta::Attribute->new };
    ok( my $err = $@, "Get attribute construction exception");
    like( $err, qr/Package 'Class::Meta::TestPerson' cannot create/,
        "Caught proper exception");

    # Now try it without a name.
    eval{ $c->add_attribute() };
    ok( $err = $@, "Caught no name exception");
    like( $err, qr/Parameter 'name' is required in call to new/,
        "Caught proper no name exception");

    # Try a duplicately-named attribute.
    eval{ $c->add_attribute(name => 'inst') };
    ok( $err = $@, "Caught dupe name exception");
    like( $err, qr/Attribute 'inst' already exists in class/,
        "Caught proper dupe name exception");

    # Try a couple of bogus visibilities.
    eval { $c->add_attribute( name => 'new_attr',
                         view  => 25) };
    ok( $err = $@, "Caught bogus view exception");
    like( $err, qr/Not a valid view parameter: '25'/,
        "Caught proper bogus view exception");
    eval { $c->add_attribute( name => 'new_attr',
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
    sub new_attr { 22 }
    ok( $attr = $c->add_attribute( name => 'new_attr' ), "Create 'new_attr'" );
    isa_ok($attr, 'Class::Meta::Attribute');

    # Test its accessors.
    is( $attr->name, "new_attr", "Check new_attr name" );
    ok( ! defined $attr->desc, "Check new_attr desc" );
    ok( ! defined $attr->label, "Check new_attr label" );
    ok( $attr->view == Class::Meta::PUBLIC, "Check new_attr view" );
}

# Now try subclassing Class::Meta.

package Class::Meta::SubClass;
use base 'Class::Meta';
sub add_attribute {
    Class::Meta::Attribute->new( shift->SUPER::class, @_);
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

    sub foo_attr { bless {} }
    ok( my $attr = $c->add_attribute( name => 'foo_attr'),
        'Create subclassed foo_attr' );

    isa_ok($attr, 'Class::Meta::Attribute');

    # Test its accessors.
    is( $attr->name, "foo_attr", "Check new foo_attr name" );
    ok( ! defined $attr->desc, "Check new foo_attr desc" );
    ok( ! defined $attr->label, "Check new foo_attr label" );
    ok( $attr->view == Class::Meta::PUBLIC, "Check new foo_attr view" );
}

##############################################################################
# Now try subclassing Class::Meta::Attribute.
package Class::Meta::Attribute::Sub;
use base 'Class::Meta::Attribute';

# Make sure we can override new and build.
sub new { shift->SUPER::new(@_) }
sub build { shift->SUPER::build(@_) }

sub foo { shift->{foo} }

package main;
ok( my $cm = Class::Meta->new(
    attribute_class => 'Class::Meta::Attribute::Sub',
), "Create Class" );
ok( my $attr = $cm->add_attribute(name => 'foo', foo => 'bar'),
    "Add foo attribute" );
isa_ok($attr, 'Class::Meta::Attribute::Sub');
isa_ok($attr, 'Class::Meta::Attribute');
is( $attr->name, 'foo', "Check an attibute");
is( $attr->foo, 'bar', "Check added attribute" );

