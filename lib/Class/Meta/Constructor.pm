package Class::Meta::Constructor;

# $Id: Constructor.pm 2877 2006-05-29 22:18:16Z theory $

=head1 NAME

Class::Meta::Constructor - Class::Meta class constructor introspection

=head1 SYNOPSIS

  # Assuming MyApp::Thingy was generated by Class::Meta.
  my $class = MyApp::Thingy->my_class;

  print "\nConstructors:\n";
  for my $ctor ($class->constructors) {
      print "  o ", $ctor->name, $/;
      my $thingy = $ctor->call($class->package);
  }

=head1 DESCRIPTION

This class provides an interface to the C<Class::Meta> objects that describe
class constructors. It supports a simple description of the constructor, a
label, and the constructor visibility (private, protected, trusted,or public).

Class::Meta::Constructor objects are created by Class::Meta; they are never
instantiated directly in client code. To access the constructor objects for a
Class::Meta-generated class, simply call its C<my_class()> method to retrieve
its Class::Meta::Class object, and then call the C<constructors()> method on
the Class::Meta::Class object.

=cut

##############################################################################
# Dependencies                                                               #
##############################################################################
use strict;

##############################################################################
# Package Globals                                                            #
##############################################################################
our $VERSION = "0.53";

##############################################################################
# Constructors                                                               #
##############################################################################

=head1 INTERFACE

=head2 Constructors

=head3 new

A protected method for constructing a Class::Meta::Constructor object. Do not
call this method directly; Call the
L<C<add_constructor()>|Class::Meta/"add_constructor"> method on a Class::Meta
object, instead.

=cut

sub new {
    my $pkg = shift;
    my $class = shift;

    # Check to make sure that only Class::Meta or a subclass is constructing a
    # Class::Meta::Constructor object.
    my $caller = caller;
    Class::Meta->handle_error("Package '$caller' cannot create $pkg "
                              . "objects")
      unless UNIVERSAL::isa($caller, 'Class::Meta')
        || UNIVERSAL::isa($caller, __PACKAGE__);

    # Make sure we can get all the arguments.
    $class->handle_error("Odd number of parameters in call to new() when "
                         . "named parameters were expected")
      if @_ % 2;
    my %p = @_;

    # Validate the name.
    $class->handle_error("Parameter 'name' is required in call to new()")
      unless $p{name};
    $class->handle_error("Constructor '$p{name}' is not a valid constructor "
                         . "name -- only alphanumeric and '_' characters "
                         . "allowed")
      if $p{name} =~ /\W/;

    # Make sure the name hasn't already been used for another constructor or
    # method.
    $class->handle_error("Method '$p{name}' already exists in class "
                         . "'$class->{package}'")
      if exists $class->{ctors}{$p{name}}
      or exists $class->{meths}{$p{name}};

    # Check the visibility.
    if (exists $p{view}) {
        $class->handle_error("Not a valid view parameter: '$p{view}'")
          unless $p{view} == Class::Meta::PUBLIC
          ||     $p{view} == Class::Meta::PROTECTED
          ||     $p{view} == Class::Meta::TRUSTED
          ||     $p{view} == Class::Meta::PRIVATE;
    } else {
        # Make it public by default.
        $p{view} = Class::Meta::PUBLIC;
    }

    # Use passed code or create the constructor?
    if ($p{code}) {
        my $ref = ref $p{code};
        $class->handle_error(
            'Parameter code must be a code reference'
        ) unless $ref && $ref eq 'CODE';
        $p{create} = 0;
    } else {
        $p{create} = 1 unless exists $p{create};
    }

    # Validate or create the method caller if necessary.
    if ($p{caller}) {
        my $ref = ref $p{caller};
        $class->handle_error("Parameter caller must be a code reference")
          unless $ref && $ref eq 'CODE';
    } else {
        $p{caller} = UNIVERSAL::can($class->{package}, $p{name})
          unless $p{create};
    }

    # Create and cache the constructor object.
    $p{package} = $class->{package};
    $class->{ctors}{$p{name}} = bless \%p, ref $pkg || $pkg;

    # Index its view.
    push @{ $class->{all_ctor_ord} }, $p{name};
    if ($p{view} > Class::Meta::PRIVATE) {
        push @{$class->{prot_ctor_ord}}, $p{name}
          unless $p{view} == Class::Meta::TRUSTED;
        if ($p{view} > Class::Meta::PROTECTED) {
            push @{$class->{trst_ctor_ord}}, $p{name};
            push @{$class->{ctor_ord}}, $p{name}
              if $p{view} == Class::Meta::PUBLIC;
        }
    }

    # Store a reference to the class object.
    $p{class} = $class;

    # Let 'em have it.
    return $class->{ctors}{$p{name}};
}


##############################################################################
# Instance Methods                                                           #
##############################################################################

=head2 Instance Methods

=head3 name

  my $name = $ctor->name;

Returns the constructor name.

=head3 package

  my $package = $ctor->package;

Returns the package name of the class that constructor is associated with.

=head3 desc

  my $desc = $ctor->desc;

Returns the description of the constructor.

=head3 label

  my $desc = $ctor->label;

Returns label for the constructor.

=head3 view

  my $view = $ctor->view;

Returns the view of the constructor, reflecting its visibility. The possible
values are defined by the following constants:

=over 4

=item Class::Meta::PUBLIC

=item Class::Meta::PRIVATE

=item Class::Meta::TRUSTED

=item Class::Meta::PROTECTED

=back

=head3 class

  my $class = $ctor->class;

Returns the Class::Meta::Class object that this constructor is associated
with. Note that this object will always represent the class in which the
constructor is defined, and I<not> any of its subclasses.

=cut

sub name    { $_[0]->{name}    }
sub package { $_[0]->{package} }
sub desc    { $_[0]->{desc}    }
sub label   { $_[0]->{label}   }
sub view    { $_[0]->{view}    }
sub class   { $_[0]->{class}   }

=head3 call

  my $obj = $ctor->call($package, @params);

Executes the constructor. Pass in the name of the class for which it is being
executed (since, thanks to subclassing, it may be different than the class
with which the constructor is associated). All other parameters will be passed
to the constructor. Note that it uses a C<goto> to execute the constructor, so
the call to C<call()> itself will not appear in a call stack trace.

=cut

sub call {
    my $self = shift;
    my $code = $self->{caller} or $self->class->handle_error(
        q{Cannot call constructor '}, $self->name, q{'}
    );
    goto &$code;
}

##############################################################################

=head3 build

  $ctor->build($class);

This is a protected method, designed to be called only by the Class::Meta
class or a subclass of Class::Meta. It takes a single argument, the
Class::Meta::Class object for the class in which the constructor was defined,
and generates constructor method for the Class::Meta::Constructor, either by
installing the code reference passed in the C<code> parameter or by creating
the constructor from scratch.

Although you should never call this method directly, subclasses of
Class::Meta::Constructor may need to override its behavior.

=cut

sub build {
    my ($self, $specs) = @_;

    # Check to make sure that only Class::Meta or a subclass is building
    # constructors.
    my $caller = caller;
    $self->class->handle_error("Package '$caller' cannot call " . ref($self)
                               . "->build")
      unless UNIVERSAL::isa($caller, 'Class::Meta')
        || UNIVERSAL::isa($caller, __PACKAGE__);

    # Just bail if we're not creating or installing the constructor.
    return $self unless delete $self->{create} || $self->{code};

    # Build a construtor that takes a parameter list and assigns the
    # the values to the appropriate attributes.
    my $name = $self->name;

    my $sub = delete $self->{code} || sub {
        my $package = ref $_[0] ? ref shift : shift;
        my $class = $specs->{$package};

        # Throw an exception for attempts to create items of an abstract
        # class.
        $class->handle_error(
            "Cannot construct objects of astract class $package"
        ) if $class->abstract;

        # Just grab the parameters and let an error be thrown by Perl
        # if there aren't the right number of them.
        my %p = @_;
        my $new = bless {}, $package;

        # Assign all of the attribute values.
        if (my $attrs = $class->{attrs}) {
            foreach my $attr (@{ $attrs }{ @{ $class->{all_attr_ord} } }) {
                # Skip class attributes.
                next if $attr->context == Class::Meta::CLASS;
                my $key = $attr->name;
                if (exists $p{$key} && $attr->authz >= Class::Meta::SET) {
                    # Let them set the value.
                    $attr->set($new, delete $p{$key});
                } else {
                    # Use the default value.
                    $new->{$key} = $attr->default unless exists $new->{$key};
                }
            }
        }

        # Check for params for which attributes are private or don't exist.
        if (my @attributes = keys %p) {
            # Attempts to assign to non-existent attributes fail.
            my $c = $#attributes > 0 ? 'attributes' : 'attribute';
            local $" = "', '";
            $class->handle_error(
                "No such $c '@attributes' in $self->{package} objects"
            );
        }
        return $new;
    };

    # Add protected, private, or trusted checks, if required.
    if ($self->view == Class::Meta::PROTECTED) {
        my $real_sub = $sub;
        my $pkg      = $self->package;
        my $class    = $self->class;
        $sub = sub {
             $class->handle_error("$name is a protected constrctor of $pkg")
                 unless caller->isa($pkg);
             goto &$real_sub;
        };
    } elsif ($self->view == Class::Meta::PRIVATE) {
        my $real_sub = $sub;
        my $pkg      = $self->package;
        my $class    = $self->class;
        $sub = sub {
            $class->handle_error("$name is a private constructor of $pkg")
                unless caller eq $pkg;
             goto &$real_sub;
         };
    }

    # Install the constructor.
    $self->{caller} ||= $sub;
    no strict 'refs';
    *{"$self->{package}::$name"} = $sub;
}

1;
__END__

=head1 BUGS

Please send bug reports to <bug-class-meta@rt.cpan.org> or report them via the
CPAN Request Tracker at L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Meta>.

=head1 AUTHOR

David Wheeler <david@kineticode.com>

=head1 SEE ALSO

Other classes of interest within the Class::Meta distribution include:

=over 4

=item L<Class::Meta|Class::Meta>

=item L<Class::Meta::Class|Class::Meta::Class>

=item L<Class::Meta::Method|Class::Meta::Method>

=item L<Class::Meta::Attribute|Class::Meta::Attribute>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2006, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
