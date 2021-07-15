require 'spree/testing_support/common_rake'

desc 'Generates a dummy app for testing an extension'
namespace :extension do
  task :test_app, [:user_class] do |_t, args|
    Spree::DummyGeneratorHelper.inject_extension_requirements = true
    Rake::Task['common:test_app'].execute(args.with_defaults(install_admin: true, install_storefront: true))
  end
end
