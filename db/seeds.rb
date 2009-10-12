require 'active_record/fixtures'
  
def yaml_to_database(fixture, path)
  ActiveRecord::Base.establish_connection(RAILS_ENV)
  tables = Dir.new(path).entries.select{|e| e =~ /(.+)?\.yml/}.collect{|c| c.split('.').first}
  Fixtures.create_fixtures(path, tables)
end

# load setup data from seeds
fixture = "default"
directory = "#{SPREE_ROOT}/db/#{fixture}"

puts "loading fixtures from #{directory}"
yaml_to_database(fixture, directory)
puts "done."

puts "Loading db/seeds.rb for each extension"
extension_roots = Spree::ExtensionLoader.instance.load_extension_roots
extension_roots.each do |extension_root|
  seeds = "#{extension_root}/db/seeds.rb"
  require seeds if File.exists? seeds
end
