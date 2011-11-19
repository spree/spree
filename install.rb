require 'fileutils'

version = ARGV.pop

%w( core auth api dash promo sample ).each do |framework|
  puts "Installing #{framework}..."
  `cd #{framework} && gem build spree_#{framework}.gemspec && gem install spree_#{framework}-#{version}.gem --no-ri --no-rdoc`
  FileUtils.remove `#{framework}\spree_#{framework}-#{version}.gem`
end

puts "Installing Spree..."
  `gem build spree.gemspec`
  `gem install spree-#{version}.gem --no-ri --no-rdoc `
FileUtils.remove `spree-#{version}.gem`
