use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'MR::Rest',
    MAKEFILE  => 'Makefile',
    PREREQ_PM => {
        'File::Map'       => 0,
        'HTTP::Headers'   => 0,
        'JSON::XS'        => 0,
        'Mouse'           => 0,
        'URI::Escape::XS' => 0,
    },
);
