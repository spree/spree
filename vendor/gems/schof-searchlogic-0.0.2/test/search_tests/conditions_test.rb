require File.dirname(__FILE__) + '/../test_helper.rb'

module SearchTests
  class TestSearchConditions < ActiveSupport::TestCase
    def test_conditions
      search = Account.new_search
      assert_kind_of Searchlogic::Conditions::Base, search.conditions
      assert_equal search.conditions.klass, Account
  
      search.conditions = {:name_like => "Binary"}
      assert_kind_of Searchlogic::Conditions::Base, search.conditions
    
      search = Account.new_search(:conditions => {:name_like => "Ben"})
      assert_equal({:name_like => "Ben"}, search.conditions.conditions)
    end

    def test_sanitize
      # This is tested in test_search_base
    end
  end
end