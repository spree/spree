# `rake spree:openapi:generate` for an extension: runs its integration specs
# through rswag and writes the `openapi/admin.yaml` its gem ships. Under
# OPENAPI=true the run is reproducible (see deterministic_openapi.rb), so a
# diff in the file means the API changed.
#
# RSpec is started only when the task runs, so a Rakefile that loads this
# keeps working in a bundle without rspec-core.
namespace :spree do
  namespace :openapi do
    desc "Generate openapi/admin.yaml from this extension's integration specs"
    task :generate do
      pattern = ENV.fetch('PATTERN', 'spec/integration/**/*_spec.rb')
      ENV['OPENAPI'] = 'true'
      ruby '-S', 'rspec', '--pattern', pattern, '--format', 'Rswag::Specs::SwaggerFormatter', '--order', 'defined'
    end
  end
end
