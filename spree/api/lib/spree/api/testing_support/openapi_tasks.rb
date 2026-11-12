# `rake spree:openapi:generate` for an extension or a Spree application: runs
# its integration specs through rswag and writes the `openapi/admin.yaml` it
# ships, and `openapi/store.yaml` when it documents Store API endpoints. Under
# OPENAPI=true the run is reproducible (see deterministic_openapi.rb), so a
# diff in a file means the API changed.
#
# RSpec is started only when the task runs, so a Rakefile that loads this
# keeps working in a bundle without rspec-core. Defined once, however many
# times it is loaded: a second definition would run the specs twice.
unless Rake::Task.task_defined?('spree:openapi:generate')
  namespace :spree do
    namespace :openapi do
      desc 'Generate the openapi/*.yaml documents from the integration specs here'
      task :generate do
        pattern = ENV.fetch('PATTERN', 'spec/integration/**/*_spec.rb')
        ENV['OPENAPI'] = 'true'
        ruby '-S', 'rspec', '--pattern', pattern, '--format', 'Rswag::Specs::SwaggerFormatter', '--order', 'defined'
      end
    end
  end
end
