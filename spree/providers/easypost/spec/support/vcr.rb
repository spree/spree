require 'vcr'
require 'webmock/rspec'

WebMock.disable_net_connect!(net_http_connect_on_start: true, allow_localhost: true)

# Cassettes were authored from EasyPost's documented response shapes; to
# re-record against the live test API, delete spec/vcr/* and run the suite
# with EASYPOST_TEST_API_KEY set.
VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = false
  c.cassette_library_dir = File.join(SpreeEasyPost::Engine.root, 'spec', 'vcr')
  c.hook_into :webmock
  c.ignore_localhost = true
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :new_episodes }
  c.filter_sensitive_data('<EASYPOST_TEST_API_KEY>') { ENV['EASYPOST_TEST_API_KEY'] }

  c.before_record do |interaction|
    interaction.request.headers['Authorization'] = ['<FILTERED>']
  end
end
