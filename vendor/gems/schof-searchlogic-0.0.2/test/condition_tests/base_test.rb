require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class BaseTest < ActiveSupport::TestCase
    def test_condition_type_name
      assert_equal "equals", Searchlogic::Condition::Equals.condition_type_name
      assert_equal "keywords", Searchlogic::Condition::Keywords.condition_type_name
      assert_equal "greater_than_or_equal_to", Searchlogic::Condition::GreaterThanOrEqualTo.condition_type_name
    end
  
    def test_ignore_meaningless_value?
      assert !Searchlogic::Condition::Equals.ignore_meaningless_value?
      assert Searchlogic::Condition::Keywords.ignore_meaningless_value?
      assert !Searchlogic::Condition::NotEqual.ignore_meaningless_value?
    end
  
    def test_value_type
      assert_nil Searchlogic::Condition::Equals.value_type
      assert_nil Searchlogic::Condition::Keywords.value_type
      assert_equal :boolean, Searchlogic::Condition::Nil.value_type
      assert_equal :boolean, Searchlogic::Condition::Blank.value_type
      assert_nil Searchlogic::Condition::GreaterThan.value_type
    end
  
    def test_initialize
      condition = Searchlogic::Condition::Keywords.new(Account, :column => Account.columns_hash["name"])
      assert_equal condition.klass, Account
      assert_equal Account.columns_hash["name"], condition.column
    
      condition = Searchlogic::Condition::GreaterThan.new(Account, :column => "id")
      assert_equal Account.columns_hash["id"], condition.column
    
      condition = Searchlogic::Condition::GreaterThan.new(Account, :column => "id", :column_type => :string, :column_sql_format => "some sql")
      assert_equal Account.columns_hash["id"], condition.column
      condition.value = "awesome"
      assert_equal ["some sql > ?", "awesome"], condition.sanitize
    end
  
    def test_explicitly_set_value
      condition = Searchlogic::Condition::Keywords.new(Account, :column => Account.columns_hash["name"])
      assert !condition.explicitly_set_value?
      condition.value = "test"
      assert condition.explicitly_set_value?
    end
  
    def test_sanitize
      # This is tested thoroughly in test_condition_types
    end
  
    def test_value
      # This is tested thoroughly in test_condition_types
    end
  end
end
