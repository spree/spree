ENV["RAILS_ENV"] = "test"

# these three lines required for engines-based plugins
require File.expand_path(File.dirname(__FILE__) + "/../../../../config/environment")
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper') # Load the normal Rails helper. This ensures the environment is loaded
Engines::Testing.set_fixture_path # Ensure that we are using the temporary fixture path

require 'test_help'
require 'mocha'

class Test::Unit::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  include AuthenticatedTestHelper
  include RoleRequirementTestHelper
  
  def assert_difference(object, method, difference=1)
    initial_value = object.send(method)
    yield
    assert_equal initial_value + difference, object.send(method)
  end
  
  def assert_no_difference(object, method, &block)
    assert_difference object, method, 0, &block
  end
end