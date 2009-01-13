$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'multi_rails_init'
require 'active_record' 
require 'action_view'
require 'test/unit'
require 'mocha'
require 'shoulda/rails'

require 'attribute_fu'
require 'attribute_fu/associations'
require 'attribute_fu/associated_form_helper'
require plugin_test_dir + '/../init.rb'

ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

ActiveRecord::Base.configurations = YAML::load(IO.read(plugin_test_dir + "/db/database.yml"))
ActiveRecord::Base.establish_connection(ENV["DB"] || "sqlite3mem")
ActiveRecord::Migration.verbose = false
load(File.join(plugin_test_dir, "db", "schema.rb"))

Dir["#{plugin_test_dir}/models/*.rb"].each {|file| require file }