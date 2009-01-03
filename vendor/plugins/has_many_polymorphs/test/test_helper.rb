
$VERBOSE = nil
require 'rubygems'
require 'echoe'
require 'test/unit'
require 'multi_rails_init'
require 'ruby-debug'

if defined? ENV['MULTIRAILS_RAILS_VERSION']
  ENV['RAILS_GEM_VERSION'] = ENV['MULTIRAILS_RAILS_VERSION']
end

Echoe.silence do
  HERE = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH << HERE
  # $LOAD_PATH << "#{HERE}/integration/app"
end

LOG = "#{HERE}/integration/app/log/development.log"     

### For unit tests

require 'integration/app/config/environment'
require 'test_help'

Inflector.inflections {|i| i.irregular 'fish', 'fish' }

$LOAD_PATH.unshift(Test::Unit::TestCase.fixture_path = HERE + "/fixtures")
$LOAD_PATH.unshift(HERE + "/models")
$LOAD_PATH.unshift(HERE + "/modules")

class Test::Unit::TestCase
  self.use_transactional_fixtures = !(ActiveRecord::Base.connection.is_a? ActiveRecord::ConnectionAdapters::MysqlAdapter rescue false)
  self.use_instantiated_fixtures  = false
end

Echoe.silence do
  load(HERE + "/schema.rb")
end

### For integration tests

def truncate
  system("> #{LOG}")
end

def log
  File.open(LOG, 'r') do |f|
    f.read
  end
end
