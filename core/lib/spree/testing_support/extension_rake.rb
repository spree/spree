require 'spree/testing_support/common_rake'

desc "Generates a dummy app for testing an extension"
namespace :extension do
  task :test_app, [:user_class] do |t, args|
    Spree::DummyGeneratorHelper.inject_extension_requirements = true
    Rake::Task['common:test_app'].invoke
  end
end

