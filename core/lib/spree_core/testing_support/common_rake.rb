desc "Generates a dummy app for testing"
namespace :common do
  task :test_app do
    require "#{ENV['LIB_NAME']}"

    SpreeCore::DummyGenerator.start ["--lib_name=#{ENV['LIB_NAME']}", "--database=#{ENV['DB_NAME']}"]
    SpreeCore::SiteGenerator.start ["--lib_name=#{ENV['LIB_NAME']}"]

    cmd = "bundle exec rake db:drop db:create db:migrate db:seed RAILS_ENV=test AUTO_ACCEPT=true"
    puts cmd; system cmd
  end
end
