package Class::Meta::AccessorBuilder;

# $Id: AccessorBuilder.pm 3863 2008-05-09 19:13:03Z david $

=head1 NAME

Class::Meta::AccessorBuilder - Perl style accessor generation

=head1 SYNOPSIS

  package MyApp::TypeDef;

  use strict;
  use Class::Meta::Type;
  use IO::Socket;

  my $type = Class::Meta::Type->add(
      key     => 'io_socket',
      builder => 'default',
      desc    => 'IO::Socket object',
      name    => 'IO::Socket Object'
  );

=head1 DESCRIPTION

This module provides the default accessor builder for Class::Meta. It builds
standard Perl-style accessors. For example, an attribute named "io_socket"
would have a single accessor method, C<io_socket>.

=head2 Accessors

Class::Meta::AccessorBuilder create three different types of accessors:
read-only, write-only, and read/write. The type of accessor created depends on
the value of the C<authz> attribute of the Class::Meta::Attribute for which
the accessor is being created.

For example, if the C<authz> is Class::Meta::RDWR, then the method will be
able to both read and write the attribute.

  my $value = $obj->io_socket;
  $obj->io_socket($value);

If the value of C<authz> is Class::Meta::READ, then the method will not
be able to change the value of the attribute:

  my $value = $obj->io_socket;
  $obj->io_socket($value); # Has no effect.

And finally, if the value of C<authz> is Class::Meta::WRITE, then the method
will not return the value of the attribute (why anyone would want this is
beyond me, but I provide for the sake of completeness):

  $obj->io_socket($value);
  my $value = $obj->io_socket;  # Always returns undef.

=head2 Data Type Validation

Class::Meta::AccessorBuilder uses all of the validation checks passed to it to
validate new values before assigning them to an attribute. It also checks to
see if the attribute is required, and if so, adds a check to ensure that its
value is never undefined. It does not currently check to ensure that private
and protected methods are used only in their appropriate contexts, but may do
so in a future release.

=head2 Class Attributes

If the C<context> attribute of the attribute object for which accessors are to
be built is C<Class::Meta::CLASS>, Class::Meta::AccessorBuilder will build
accessors for a class attribute instead of an object attribute. Of course,
this means that if you change the value of the class attribute in any
context--whether via a an object, the class name, or an an inherited class
name or object, the value will be changed everywhere.

For example, for a class attribute "count", you can expect the following to
work:

  MyApp::Custom->count(10);
  my $count = MyApp::Custom->count; # Returns 10.
  my $obj = MyApp::Custom->new;
  $count = $obj->count;             # Returns 10.

  $obj->count(22);
  $count = $obj->count;             # Returns 22.
  my $count = MyApp::Custom->count; # Returns 22.

  MyApp::Custom->count(35);
  $count = $obj->count;             # Returns 35.
  my $count = MyApp::Custom->count; # Returns 35.

Currently, class attribute accessors are not designed to be inheritable in the
way designed by Class::Data::Inheritable, although this might be changed in a
future release. For now, I expect that the current simple approach will cover
the vast majority of circumstances.

B<Note:> Class attribute accessors will not work accurately in multiprocess
environments such as mod_perl. If you change a class attribute's value in one
process, it will not be changed in any of the others. Furthermore, class
attributes are not currently shared across threads. So if you're using
Class::Meta class attributes in a multi-threaded environment (such as iThreads
in Perl 5.8.0 and later) the changes to a class attribute in one thread will
not be reflected in other threads.

=head1 Private and Protected Attributes

Any attributes that have their C<view> attribute set to Class::Meta::Private
or Class::Meta::Protected get additional validation installed to ensure that
they're truly private or protected. This includes when they are set via
parameters to constructors generated by Class::Meta. The validation is
performed by checking the caller of the accessors, and throwing an exception
when the caller isn't the class that owns the attribute (for private
attributes) or when it doesn't inherit from the class that owns the attribute
(for protected attributes).

As an implementation note, this validation is performed for parameters passed
to constructors created by Class::Meta by ignoring looking for the first
caller that isn't Class::Meta::Constructor:

  my $caller = caller;
  # Circumvent generated constructors.
  for (my $i = 1; $caller eq 'Class::Meta::Constructor'; $i++) {
      $caller = caller($i);
  }

This works because Class::Meta::Constructor installs the closures that become
constructors, and thus, when those closures call accessors to set new values
for attributes, the caller is Class::Meta::Constructor. By going up the stack
until we find another package, we correctly check to see what context is
setting attribute values via a constructor, rather than the constructor method
itself being the context.

This is a bit of a hack, but since Perl uses call stacks for checking security
in this way, it's the best I could come up with. Other suggestions welcome. Or
see L<Class::Meta::Type|Class::Meta::Type/"Custom Accessor Building"> to
create your own accessor generation code

=head1 INTERFACE

The following functions must be implemented by any Class::Meta accessor
generation module.

=head2 Functions

=head3 build_attr_get

  my $code = Class::Meta::AccessorBuilder::build_attr_get();

This function is called by C<Class::Meta::Type::make_attr_get()> and returns a
code reference that can be used by the C<get()> method of
Class::Meta::Attribute to return the value stored for that attribute for the
object passed to the code reference.

=head3 build_attr_set

  my $code = Class::Meta::AccessorBuilder::build_attr_set();

This function is called by C<Class::Meta::Type::make_attr_set()> and returns a
code reference that can be used by the C<set()> method of
Class::Meta::Attribute to set the value stored for that attribute for the
object passed to the code reference.

=head3 build

  Class::Meta::AccessorBuilder::build($pkg, $attribute, $create, @checks);

This method is called by the C<build()> method of Class::Meta::Type, and does
the work of actually generating the accessors for an attribute object. The
arguments passed to it are:

=over 4

=item $pkg

The name of the class to which the accessors will be added.

=item $attribute

The Class::Meta::Attribute object that specifies the attribute for which the
accessors will be created.

=item $create

The value of the C<create> attribute of the Class::Meta::Attribute object,
which determines what accessors, if any, are to be created.

=item @checks

A list of code references that validate the value of an attribute. These will
be used in the set accessor (mutator) to validate new attribute values.

=back

=cut

use strict;
use Class::Meta;
our $VERSION = '0.60';

sub build_attr_get {
    UNIVERSAL::can($_[0]->package, $_[0]->name);
}

sub build_attr_set { &build_attr_get }

my $req_chk = sub {
    $_[2]->class->handle_error('Attribute ', $_[2]->name, ' must be defined')
      unless defined $_[0];
};

my $once_chk = sub {
    $_[2]->class->handle_error(
        'Attribute ', $_[2]->name, ' can only be set once'
    ) if defined $_[1]->{$_[2]->name};
};

sub build {
    my ($pkg, $attr, $create, @checks) = @_;
    my $name = $attr->name;

    # Add the required check, if needed.
    unshift @checks, $req_chk if $attr->required;

    # Add a once check, if needed.
    unshift @checks, $once_chk if $attr->once;

    my $sub;
    if ($attr->context == Class::Meta::CLASS) {
        # Create class attribute accessors by creating a closure that
        # references this variable.
        my $data = $attr->default;

        if ($create == Class::Meta::GET) {
            # Create GET accessor.
            $sub = sub { $data };

        } elsif ($create == Class::Meta::SET) {
            # Create SET accessor.
            if (@checks) {
                $sub = sub {
                    # Check the value passed in.
                    $_->($_[1], { $name => $data,
                                  __pkg => ref $_[0] || $_[0] },
                         $attr) for @checks;
                    # Assign the value.
                    $data = $_[1];
                    return;
                };
            } else {
                $sub = sub {
                    # Assign the value.
                    $data = $_[1];
                    return;
                };
            }

        } elsif ($create == Class::Meta::GETSET) {
            # Create GETSET accessor(s).
            if (@checks) {
                $sub = sub {
                    my $self = shift;
                    return $data unless @_;
                    # Check the value passed in.
                    $_->($_[1], { $name => $data,
                                  __pkg => ref $self || $self },
                         $attr) for @checks;
                    # Assign the value.
                    return $data = $_[0];
                };
            } else {
                $sub = sub {
                    my $self = shift;
                    return $data unless @_;
                    # Assign the value.
                    return $data = shift;
                };
            }
        } else {
            # Well, nothing I guess.
        }
    } else {
        # Create object attribute accessors.
        if ($create == Class::Meta::GET) {
            # Create GET accessor.
            $sub = sub { $_[0]->{$name} };

        } elsif ($create == Class::Meta::SET) {
            # Create SET accessor.
            if (@checks) {
                $sub = sub {
                    # Check the value passed in.
                    $_->($_[1], $_[0], $attr) for @checks;
                    # Assign the value.
                    $_[0]->{$name} = $_[1];
                    return;
                };
            } else {
                $sub = sub {
                    # Assign the value.
                    $_[0]->{$name} = $_[1];
                    return;
                };
            }

        } elsif ($create == Class::Meta::GETSET) {
            # Create GETSET accessor(s).
            if (@checks) {
                $sub = sub {
                    my $self = shift;
                    return $self->{$name} unless @_;
                    # Check the value passed in.
                    $_->($_[0], $self, $attr) for @checks;
                    # Assign the value.
                    return $self->{$name} = $_[0];
                };
            } else {
                $sub = sub {
                    my $self = shift;
                    return $self->{$name} unless @_;
                    # Assign the value.
                    return $self->{$name} = shift;
                };
            }
        } else {
            # Well, nothing I guess.
        }
    }

    # Add public and private checks, if required.
    if ($attr->view == Class::Meta::PROTECTED) {
        my $real_sub = $sub;
         $sub = sub {
             my $caller = caller;
             # Circumvent generated constructors.
             for (my $i = 1; $caller eq 'Class::Meta::Constructor'; $i++) {
                 $caller = caller($i);
             }

             $attr->class->handle_error("$name is a protected attribute "
                                        . "of $pkg")
               unless UNIVERSAL::isa($caller, $pkg);
             goto &$real_sub;
        };
    } elsif ($attr->view == Class::Meta::PRIVATE) {
        my $real_sub = $sub;
        $sub = sub {
             my $caller = caller;
             # Circumvent generated constructors.
             for (my $i = 1; $caller eq 'Class::Meta::Constructor'; $i++) {
                 $caller = caller($i);
             }

             $attr->class->handle_error("$name is a private attribute of $pkg")
               unless $caller eq $pkg;
             goto &$real_sub;
         };
    } elsif ($attr->view == Class::Meta::TRUSTED) {
        my $real_sub = $sub;
        my $trusted = $attr->class->trusted;
        $sub = sub {
             my $caller = caller;
             # Circumvent generated constructors.
             for (my $i = 1; $caller eq 'Class::Meta::Constructor'; $i++) {
                 $caller = caller($i);
             }

             goto &$real_sub if $caller eq $pkg;
             for my $pack (@{$trusted}) {
                 goto &$real_sub if UNIVERSAL::isa($caller, $pack);
             }
             $attr->class->handle_error("$name is a trusted attribute of $pkg");
         };
    }

    # Install the accessor.
    no strict 'refs';
    *{"${pkg}::$name"} = $sub;
}

1;
__END__

=head1 SUPPORT

This module is stored in an open repository at the following address:

L<https://svn.kineticode.com/Class-Meta/trunk/>

Patches against Class::Meta are welcome. Please send bug reports to
<bug-class-meta@rt.cpan.org>.

=head1 AUTHOR

David Wheeler <david@kineticode.com>

=head1 SEE ALSO

=over 4

=item L<Class::Meta|Class::Meta>

This class contains most of the documentation you need to get started with
Class::Meta.

=item L<Class::Meta::AccessorBuilder::Affordance|Class::Meta::AccessorBuilder::Affordance>

This module generates affordance style accessors (e.g., C<get_foo()> and
C<set_foo()>.

=item L<Class::Meta::AccessorBuilder::SemiAffordance|Class::Meta::AccessorBuilder::SemiAffordance>

This module generates semi-affordance style accessors (e.g., C<foo()> and
C<set_foo()>.

=item L<Class::Meta::Type|Class::Meta::Type>

This class manages the creation of data types.

=item L<Class::Meta::Attribute|Class::Meta::Attribute>

This class manages Class::Meta class attributes, most of which will have
generated accessors.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2008, David Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
