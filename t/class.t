#!/usr/bin/perl -w

# $Id: class.t 2893 2006-05-30 23:59:28Z david $

use strict;
use Test::More tests => 13;
BEGIN { use_ok( 'Class::Meta') }

# Make sure we can't instantiate a class object from here.
my $class;
eval { $class = Class::Meta::Class->new };
ok( my $err = $@, 'Error creating class' );
like($err, qr/^Package 'main' cannot create.*objects/,
     'Check error message' );

# Now try inheritance.
package Class::Meta::FooSub;
use strict;
use base 'Class::Meta';
Test::More->import;

# Set up simple settings.
my $spec = { desc  => 'Foo Class description',
             package => 'FooClass',
             class => Class::Meta->new->class,
             error_handler => Class::Meta->default_error_handler,
             key   => 'foo' };

# This should be okay.
ok( $class = Class::Meta::Class->new($spec),
          'Subclass can create class objects' );

# Test the simple accessors.
is( $class->name, ucfirst $spec->{key}, 'name' );
is( $class->desc, $spec->{desc}, 'desc' );
is( $class->key, $spec->{key}, 'key' );

# Now try inheritance for Class.
package Class::Meta::Class::Sub;
use base 'Class::Meta::Class';

# Make sure we can override new and build.
sub new { shift->SUPER::new(@_) }
sub build { shift->SUPER::build(@_) }

sub foo { shift->{foo} }

package main;
ok( my $cm = Class::Meta->new(
    class_class => 'Class::Meta::Class::Sub',
    foo         => 'bar',
), "Create Class" );
ok( $class = $cm->class, "Retrieve class" );
isa_ok($class, 'Class::Meta::Class::Sub');
isa_ok($class, 'Class::Meta::Class');
is( $class->package, __PACKAGE__, "Check an attibute");
is( $class->foo, 'bar', "Check added attribute" );

