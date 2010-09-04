require 'rake'
require 'rake/gempackagetask'

PROJECTS = %w(core api auth dash sample)  #TODO - spree_promotions

spec = eval(File.read('spree.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Release all gems to gemcutter. Package rails, package & push components, then push spree"
task :release => :release_projects do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

# desc "Release all components to gemcutter."
# task :release_projects => :package do
#   errors = []
#   PROJECTS.each do |project|
#     system(%(cd #{project} && #{$0} release)) || errors << project
#   end
#   fail("Errors in #{errors.join(', ')}") unless errors.empty?
# end