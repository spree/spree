require 'rubygems'
require 'hoe'
require './lib/spec/rails/version'
require 'cucumber/rake/task'

$:.unshift(File.join(File.dirname(__FILE__), "/../rspec/lib"))

require 'spec/rake/spectask'

class Hoe
  def extra_deps
    @extra_deps.reject! { |x| Array(x).first == 'hoe' }
    @extra_deps
  end
end

Hoe.new('rspec-rails', Spec::Rails::VERSION::STRING) do |p|
  p.summary = Spec::Rails::VERSION::SUMMARY
  p.url = 'http://rspec.info/'
  p.description = "Behaviour Driven Development for Ruby on Rails."
  p.rubyforge_name = 'rspec'
  p.developer('RSpec Development Team', 'rspec-devel@rubyforge.org')
  p.extra_deps = [["rspec","1.1.12"]]
  p.extra_dev_deps = [["cucumber",">= 0.1.13"]]
  p.remote_rdoc_dir = "rspec-rails/#{Spec::Rails::VERSION::STRING}"
end

['audit','test','test_deps','default','post_blog', 'release'].each do |task|
  Rake.application.instance_variable_get('@tasks').delete(task)
end

task :release => [:clean, :package] do |t|
  version = ENV["VERSION"] or abort "Must supply VERSION=x.y.z"
  abort "Versions don't match #{version} vs #{Spec::Rails::VERSION::STRING}" unless version == Spec::Rails::VERSION::STRING
  pkg = "pkg/rspec-rails-#{version}"

  rubyforge = RubyForge.new.configure
  puts "Logging in to rubyforge ..."
  rubyforge.login

  puts "Releasing rspec-rails version #{version} ..."
  ["#{pkg}.gem", "#{pkg}.tgz"].each do |file|
    rubyforge.add_file('rspec', 'rspec', Spec::Rails::VERSION::STRING, file)
  end
end

Spec::Rake::SpecTask.new

Cucumber::Rake::Task.new

task :default => [:features]