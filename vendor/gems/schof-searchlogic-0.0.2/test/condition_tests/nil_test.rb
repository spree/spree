require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class NilTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = true
      assert_equal "\"accounts\".\"id\" IS NULL", condition.sanitize
    
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = false
      assert_equal "\"accounts\".\"id\" IS NOT NULL", condition.sanitize
    
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = "true"
      assert_equal "\"accounts\".\"id\" IS NULL", condition.sanitize
    
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = "false"
      assert_equal "\"accounts\".\"id\" IS NOT NULL", condition.sanitize
    
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = nil
      assert_nil condition.sanitize
    
      condition = Searchlogic::Condition::Nil.new(Account, :column => Account.columns_hash["id"])
      condition.value = ""
      assert_nil condition.sanitize
    end
  end
end