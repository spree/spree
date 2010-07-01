require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'

PROJECTS = %w(core)

desc 'Run all tests by default'
task :default => %w(test)

%w(test).each do |task_name|
  desc "Run #{task_name} task for all projects"
  task task_name do
    errors = []
    PROJECTS.each do |project|
      system(%(cd #{project} && #{$0} #{task_name})) || errors << project
    end
    fail("Errors in #{errors.join(', ')}") unless errors.empty?
  end
end

