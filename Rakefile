require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

unless Rake::Task.task_defined? "spree:release"
  Dir["#{SPREE_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
end