#!/usr/bin/perl -w

# $Id: types.t 789 2004-10-28 01:25:45Z theory $

##############################################################################
# Set up the tests.
##############################################################################

use strict;
use Test::More tests => 56;

##############################################################################
# Create a simple class.
##############################################################################

package Class::Meta::TestTypes;
use strict;

BEGIN {
    $SIG{__DIE__} = \&Carp::confess;
    main::use_ok( 'Class::Meta');
    main::use_ok( 'Class::Meta::Type');
    main::use_ok( 'Class::Meta::Types::Numeric');
    main::use_ok( 'Class::Meta::Types::Perl');
    main::use_ok( 'Class::Meta::Types::String');
    main::use_ok( 'Class::Meta::Types::Boolean');
    @Bart::ISA = qw(Simpson);
}

BEGIN {
    # Add the new data type.
    Class::Meta::Type->add( key       => 'simpson',
                            name      => 'Simpson',
                            desc      => 'An Simpson object.',
                            check     => 'Simpson',
                        );

    my $c = Class::Meta->new(package => __PACKAGE__,
                             key     => 'types',
                             name    => 'Class::Meta::TestTypes Class',
                             desc    => 'Just for testing Class::Meta.'
                         );
    $c->add_constructor(name => 'new');

    $c->add_attribute( name  => 'name',
                  view   => Class::Meta::PUBLIC,
                  type  => 'string',
                  length   => 256,
                  label => 'Name',
                  field => 'text',
                  desc  => "The person's name.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'age',
                  view   => Class::Meta::PUBLIC,
                  type  => 'integer',
                  label => 'Age',
                  field => 'text',
                  desc  => "The person's age.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'alive',
                  view   => Class::Meta::PUBLIC,
                  type  => 'boolean',
                  label => 'Living',
                  field => 'checkbox',
                  desc  => "Is the person alive?",
                  required   => 0,
                  default   => 1,
              );
    $c->add_attribute( name  => 'whole',
                  view   => Class::Meta::PUBLIC,
                  type  => 'whole',
                  label => 'A whole number.',
                  field => 'text',
                  desc  => "A whole number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'dec',
                  view   => Class::Meta::PUBLIC,
                  type  => 'decimal',
                  label => 'A decimal number.',
                  field => 'text',
                  desc  => "A decimal number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'real',
                  view   => Class::Meta::PUBLIC,
                  type  => 'real',
                  label => 'A real number.',
                  field => 'text',
                  desc  => "A real number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'float',
                  view   => Class::Meta::PUBLIC,
                  type  => 'float',
                  label => 'A float.',
                  field => 'text',
                  desc  => "A floating point number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'scalar',
                  view   => Class::Meta::PUBLIC,
                  type  => 'scalarref',
                  label => 'A scalar.',
                  field => 'text',
                  desc  => "A scalar reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'array',
                  view   => Class::Meta::PUBLIC,
                  type  => 'array',
                  label => 'A array.',
                  field => 'text',
                  desc  => "A array reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'hash',
                  view   => Class::Meta::PUBLIC,
                  type  => 'hash',
                  label => 'A hash.',
                  field => 'text',
                  desc  => "A hash reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attribute( name  => 'simpson',
                  view   => Class::Meta::PUBLIC,
                  type  => 'simpson',
                  label => 'A Simpson Object',
                  field => 'text',
                  desc  => 'A Simpson object.',
                  required   => 0,
                  default => sub { bless {}, 'Simpson' },
                  create   => Class::Meta::GETSET
              );

    $c->build;
}


##############################################################################
# Do the tests.
##############################################################################

package main;
# Instantiate a base class object and test its accessors.
ok( my $t = Class::Meta::TestTypes->new, 'Class::Meta::TestTypes->new');

# Grab its metadata object.
ok( my $class = $t->my_class, "Get the Class::Meta::Class object" );

# Test the is_a() method.
ok( $class->is_a('Class::Meta::TestTypes'), 'Class isa TestTypes');

# Test the key methods.
is( $class->key, 'types', 'Key is correct');

# Test the name method.
is( $class->name, 'Class::Meta::TestTypes Class', "Name is correct");

# Test the description methods.
is( $class->desc, 'Just for testing Class::Meta.',
    "Description is correct");

# Test string.
ok( $t->name('David'), 'name to "David"' );
is( $t->name, 'David', 'name is "David"' );
eval { $t->name([]) };
ok( my $err = $@, 'name to array ref croaks' );
like( $err, qr/^Value .* is not a valid string/, 'correct string exception' );

# Test boolean.
ok( $t->alive, 'alive true');
is( $t->alive(0), 0, 'alive off');
ok( !$t->alive, 'alive false');
ok( $t->alive(1), 'alive on' );
ok( $t->alive, 'alive true again');

# Test whole number.
eval { $t->whole(0) };
ok( $err = $@, 'whole to 0 croaks' );
like( $err, qr/^Value '0' is not a valid whole number/,
     'correct whole number exception' );
ok( $t->whole(1), 'whole to 1.');

# Test integer.
eval { $t->age(0.5) };
ok( $err = $@, 'age to 0.5 croaks');
like( $err, qr/^Value '0\.5' is not a valid integer/,
     'correct integer exception' );
ok( $t->age(10), 'age to 10.');

# Test decimal.
eval { $t->dec('+') };
ok( $err = $@, 'dec to "+" croaks');
like( $err, qr/^Value '\+' is not a valid decimal number/,
     'correct decimal exception' );
ok( $t->dec(3.14), 'dec to 3.14.');

# Test real.
eval { $t->real('+') };
ok( $err = $@, 'real to "+" croaks');
like( $err, qr/^Value '\+' is not a valid real number/,
     'correct real exception' );
ok( $t->real(123.4567), 'real to 123.4567.');
ok( $t->real(-123.4567), 'real to -123.4567.');

# Test float.
eval { $t->float('+') };
ok( $err = $@, 'float to "+" croaks');
like( $err, qr/^Value '\+' is not a valid floating point number/,
     'correct float exception' );
ok( $t->float(1.23e99), 'float to 1.23e99.');

# Test OBJECT with default specifying object type.
ok( my $simpson = $t->simpson, 'simpson' );
isa_ok($simpson, 'Simpson');
eval { $t->simpson('foo') };
ok( $err = $@, 'simpson to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Simpson/,
     'correct object exception' );

# Try a wrong object.
eval { $t->simpson($t) };
ok( $err = $@, 'simpson to \$fh croaks' );
like( $err, qr/^Value '.*' is not a valid Simpson/,
     'correct object exception' );
ok( $t->simpson($simpson), 'simpson to \$simpson.');

# Try a subclass.
my $bart = bless {}, 'Bart';
ok( $t->simpson($bart), "Set simpson to a subclass." );
isa_ok($t->simpson, 'Bart', "Check subclass" );
ok( $t->simpson($simpson), 'simpson to \$simpson.');

# Test SCALAR.
eval { $t->scalar('foo') };
ok( $err = $@, 'scalar to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Scalar Reference/,
     'correct scalar exception' );
ok( $t->scalar(\"foo"), 'scalar to \\"foo".');

# Test ARRAY.
eval { $t->array('foo') };
ok( $err = $@, 'array to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Array Reference/,
     'correct array exception' );
ok( $t->array(["foo"]), 'array to ["foo"].');

# Test HASH.
eval { $t->hash('foo') };
ok( $err = $@, 'hash to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Hash Reference/,
     'correct hash exception' );
ok( $t->hash({ foo => 1 }), 'hash to { foo => 1 }.');
