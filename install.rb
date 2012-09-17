require 'fileutils'

version = ARGV.pop

%w( core api dash promo sample ).each do |framework|
  puts "Installing #{framework}..."

  Dir.chdir(framework) do
    `gem build spree_#{framework}.gemspec`
    `gem install spree_#{framework}-#{version}.gem --no-ri --no-rdoc`
    FileUtils.remove "spree_#{framework}-#{version}.gem"
  end

end

puts "Installing Spree..."
  `gem build spree.gemspec`
  `gem install spree-#{version}.gem --no-ri --no-rdoc `

  FileUtils.remove "spree-#{version}.gem"
