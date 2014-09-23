package MR::Rest::Devel;

use MR::Rest;

use MR::Rest::Type;

controller 'GET /devel/route/' => (
    doc     => 'All registered controllers',
    result  => [{
        alias  => 'Str',
        method => 'Str',
        uri    => 'Str',
        doc    => 'Str',
        params => {
            'name:' => {
                name     => 'Str',
                location => 'Str',
                doc      => 'Str',
            },
        },
        result => 'Str',
    }],
    handler => sub {
        my ($c) = @_;
        my @controllers = MR::Rest->controllers();
        return [
            map +{
                alias  => $_->alias,
                method => $_->method,
                uri    => $_->uri,
                doc    => $_->doc,
                params => [
                    map +{
                        name     => $_->name,
                        location => $_->location,
                        doc      => $_->doc,
                    }, $_->params_meta->get_all_parameters(),
                ],
                result => $c->format_uri('get_devel_result_item', classname => $_->result_meta->name),
            }, @controllers
        ];
    },
);

controller 'GET /devel/result/{classname}' => (
    doc    => 'Response description',
    params => {
        classname => 'MR::Rest::Type::ResultName',
    },
    result => {
        'fields' => {
            'name:' => {
                name => 'Str',
                type => 'Str',
                doc  => 'Str',
                uri  => 'Maybe[Str]',
            },
        },
    },
    handler => sub {
        my ($c) = @_;
        return {
            fields => [
                map +{
                    name => $_->name,
                    doc  => $_->doc,
                    type => $_->type_constraint->name,
                }, $c->params->classname->meta->get_all_fields(),
            ],
        };
    },
);

no MR::Rest;
__PACKAGE__->meta->make_immutable();

1;
