require 'rspec/core/rake_task'

# `rake spree:openapi:generate` for an extension: runs its integration specs
# through rswag and writes the `openapi/admin.yaml` its gem ships. Under
# OPENAPI=true the run is reproducible (see deterministic_openapi.rb), so a
# diff in the file means the API changed.
namespace :spree do
  namespace :openapi do
    desc "Generate openapi/admin.yaml from this extension's integration specs"
    RSpec::Core::RakeTask.new(:generate) do |task|
      task.pattern = ENV.fetch('PATTERN', 'spec/integration/**/*_spec.rb')
      ENV['OPENAPI'] = 'true'
      task.rspec_opts = ['--format Rswag::Specs::SwaggerFormatter', '--order defined']
    end
  end
end
