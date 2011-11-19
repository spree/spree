version = ARGV.pop

%w( core api auth dash promo sample ).each do |framework|
  puts "Installing #{framework}..."
  `cd #{framework} && gem build spree_#{framework}.gemspec && gem install spree_#{framework}-#{version} --no-ri --no-rdoc && rm spree_#{framework}-#{version}`
end

puts "Installing Spree..."
`gem build spree.gemspec`
`gem install spree-#{version} --no-ri --no-rdoc `
`rm spree-#{version}.gem`
