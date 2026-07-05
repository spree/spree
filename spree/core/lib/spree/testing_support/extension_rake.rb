require 'spree/testing_support/common_rake'

desc 'Generates a dummy app for testing an extension'
namespace :extension do
  task :test_app, [:options] do |_t, args|
    Spree::DummyGeneratorHelper.inject_extension_requirements = true
    # Support both hash passed as first arg and named options
    options = args[:options].is_a?(Hash) ? args[:options] : args.to_h
    Rake::Task['common:test_app'].execute(Rake::TaskArguments.new(
      [:authentication, :user_class, :admin_user_class, :css, :javascript, :install_admin, :install_storefront],
      [
        options[:authentication],
        options[:user_class],
        options[:admin_user_class],
        options[:css],
        options[:javascript],
        options[:install_admin],
        options[:install_storefront]
      ]
    ))
  end
end
