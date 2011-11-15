desc "Generates a dummy app for testing"
namespace :common do
  task :test_app do
    require "#{ENV['LIB_NAME']}"

    Spree::DummyGenerator.start ["--lib_name=#{ENV['LIB_NAME']}", "--database=#{ENV['DB_NAME']}", "--quiet"]
    Spree::SiteGenerator.start ["--lib_name=#{ENV['LIB_NAME']}", "--quiet"]
    puts "Setting up dummy database..."
    cmd = "bundle exec rake db:drop db:create db:migrate db:seed RAILS_ENV=test AUTO_ACCEPT=true"
    if RUBY_PLATFORM =~ /mswin/ #windows
      cmd += " >nul"
    else
      cmd += " >/dev/null"
    end

    system(cmd)
  end
end
