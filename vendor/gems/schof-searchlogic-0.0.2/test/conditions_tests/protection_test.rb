require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionsTests
  class ProtectionTest < ActiveSupport::TestCase
    def test_protection
      assert_raise(ArgumentError) { Account.new_search(:conditions => "(DELETE FROM users)") }
      assert_nothing_raised { Account.new_search!(:conditions => "(DELETE FROM users)") }
    
      account = Account.first
    
      assert_raise(ArgumentError) { account.users.new_search(:conditions => "(DELETE FROM users)") }
      assert_nothing_raised { account.users.new_search!(:conditions => "(DELETE FROM users)") }
    
      search = Account.new_search
      assert_raise(ArgumentError) { search.conditions = "(DELETE FROM users)" }
    end
  end
end