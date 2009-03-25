require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class BlankTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = "true"
      assert_equal "(\"accounts\".\"id\" IS NULL or \"accounts\".\"id\" = '' or \"accounts\".\"id\" = false)", condition.sanitize
    
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = "false"
      assert_equal "(\"accounts\".\"id\" IS NOT NULL and \"accounts\".\"id\" != '' and \"accounts\".\"id\" != false)", condition.sanitize
    
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = true
      assert_equal "(\"accounts\".\"id\" IS NULL or \"accounts\".\"id\" = '' or \"accounts\".\"id\" = false)", condition.sanitize
    
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = false
      assert_equal "(\"accounts\".\"id\" IS NOT NULL and \"accounts\".\"id\" != '' and \"accounts\".\"id\" != false)", condition.sanitize
    
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = nil
      assert_nil condition.sanitize
    
      condition = Searchlogic::Condition::Blank.new(Account, :column => Account.columns_hash["id"])
      condition.value = ""
      assert_nil condition.sanitize
    end
  end
end