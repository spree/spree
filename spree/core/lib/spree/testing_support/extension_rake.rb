require 'spree/testing_support/common_rake'

# `rake spree:openapi:generate` writes the extension's openapi/admin.yaml from
# its rswag specs.
begin
  require 'spree/api/testing_support/openapi_tasks'
rescue LoadError
  # An extension without spree_api has no admin operations to document.
end

desc 'Generates a dummy app for testing an extension'
namespace :extension do
  task :test_app, [:options] do |_t, args|
    Spree::DummyGeneratorHelper.inject_extension_requirements = true
    # Support both hash passed as first arg and named options
    options = args[:options].is_a?(Hash) ? args[:options] : args.to_h
    Rake::Task['common:test_app'].execute(Rake::TaskArguments.new(
      [:authentication, :user_class, :admin_user_class],
      [
        options[:authentication],
        options[:user_class],
        options[:admin_user_class]
      ]
    ))
  end
end
