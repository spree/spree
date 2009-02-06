require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_support'
require 'find_by_param'
class ActiveRecord::Base
  class_inheritable_accessor :permalink_options
  self.permalink_options = {:param => :id}
end
ActiveRecord::Base.send(:include, Railslove::Plugins::FindByParam)

ActiveRecord::Base.establish_connection({
    'adapter' => 'sqlite3',
    'database' => ':memory:'
  })
load(File.join(File.dirname(__FILE__), 'schema.rb'))
