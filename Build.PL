use Module::Build;

my $build = Module::Build->new(
    module_name        => 'Class::Meta',
    license            => 'perl',
    requires            => { Data::Types => '0.05',
                             Class::ISA  => '0.31',
                           },
    build_requires     => { Test::Simple => '0.17',
                          },
    create_makefile_pl => 'passthrough',
);
$build->create_build_script;