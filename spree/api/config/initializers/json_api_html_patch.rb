# we need this until we drop Rails 8.0/7.2 support
# Rails 8.1 will have an escape: false option
# https://github.com/rails/rails/commit/8be58ff1e5519bf7a5772896896df0557f3d19e3
ActiveSupport::JSON::Encoding.escape_html_entities_in_json = false
