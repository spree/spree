require 'rake'
require 'rake/rdoctask'

desc 'Generate RDoc'
rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = '../doc/output/rdoc-rails'
  rdoc.options << '--title' << 'Spec::Rails' << '--line-numbers' << '--inline-source' << '--main' << 'Spec::Rails'
  rdoc.rdoc_files.include('MIT-LICENSE', 'lib/**/*.rb')
end
