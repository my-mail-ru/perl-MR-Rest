package MR::Rest::Responses;

use MR::Rest::Util::Response;

error_response unauthorized            => (401, 'Authorization required');
error_response forbidden               => (403, 'Access denied');
error_response invalid_content_type    => (415, 'Content-Type should be "application/x-www-form-urlencoded"');
error_response content_length_required => (411, 'Content-Length required');
error_response invalid_content_length  => (400, 'Content-Length doesn\'t match content size');
error_response request_too_large       => (413, 'Content-Length should be less then 1Mb');
error_response invalid_param           => (400, 'Invalid parameter');
error_response not_implemented         => (501, 'Not implemented');

no MR::Rest::Util::Response;

1;
