package MR::Rest::Devel;

use MR::Rest;

controller 'GET /devel/route/' => (
    doc     => 'All registered controllers',
    handler => sub {
        my ($c) = @_;
        my @controllers = MR::Rest->controllers();
        return [
            map +{
                method => $_->method,
                uri    => $_->uri,
                doc    => $_->doc,
                params => {
                    map {
                        $_->name => {
                            location => $_->location,
                            doc      => $_->doc,
                        }
                    } $_->params_meta->get_all_parameters(),
                },
            }, @controllers
        ];
    },
);

no MR::Rest;
__PACKAGE__->meta->make_immutable();

1;
