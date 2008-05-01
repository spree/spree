require 'rake'
require 'spec/rake/spectask'

desc "Run all examples with RCov"
Spec::Rake::SpecTask.new('examples_with_rcov') do |t|
  t.spec_files = FileList['examples/**/*.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'examples']
end