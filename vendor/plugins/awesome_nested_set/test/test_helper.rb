$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)
RAILS_ROOT = plugin_test_dir

require 'rubygems'
require 'test/unit'
require 'multi_rails_init'
require 'test_help'

require plugin_test_dir + '/../init.rb'

TestCaseClass = ActiveSupport::TestCase rescue Test::Unit::TestCase

ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

ActiveRecord::Base.configurations = YAML::load(IO.read(plugin_test_dir + "/db/database.yml"))
ActiveRecord::Base.establish_connection(ENV["DB"] || "sqlite3mem")
ActiveRecord::Migration.verbose = false
load(File.join(plugin_test_dir, "db", "schema.rb"))

Dir["#{plugin_test_dir}/fixtures/*.rb"].each {|file| require file }

class TestCaseClass #:nodoc:
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/"
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
  
  fixtures :categories, :notes, :departments
end
