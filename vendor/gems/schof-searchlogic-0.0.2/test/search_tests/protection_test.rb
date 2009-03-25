require File.dirname(__FILE__) + '/../test_helper.rb'

module SearchTests
  class ProtectionTest < ActiveSupport::TestCase
    def test_protection
      assert_raise(ArgumentError) { Account.build_search(:conditions => "(DELETE FROM users)", :page => 2, :per_page => 15) }
      Searchlogic::Search::Base::VULNERABLE_FIND_OPTIONS.each { |option| assert_raise(ArgumentError) { Account.build_search(option => "(DELETE FROM users)") } }
      
      assert_nothing_raised { Account.build_search!(:conditions => "(DELETE FROM users)", :page => 2, :per_page => 15) }
      Searchlogic::Search::Base::VULNERABLE_FIND_OPTIONS.each { |option| assert_nothing_raised { Account.build_search!(option => "(DELETE FROM users)") } }
      
      account = Account.first
      
      assert_raise(ArgumentError) { account.users.build_search(:conditions => "(DELETE FROM users)", :page => 2, :per_page => 15) }
      Searchlogic::Search::Base::VULNERABLE_FIND_OPTIONS.each { |option| assert_raise(ArgumentError) { account.users.build_search(option => "(DELETE FROM users)") } }
      
      assert_nothing_raised { account.users.build_search!(:conditions => "(DELETE FROM users)", :page => 2, :per_page => 15) }
      Searchlogic::Search::Base::VULNERABLE_FIND_OPTIONS.each { |option| assert_nothing_raised { account.users.build_search!(option => "(DELETE FROM users)") } }
      
      assert_raise(ArgumentError) { Account.build_search(:order_by => "unknown_column") }
      assert_nothing_raised { Account.build_search!(:order_by => "unknown_column") }
      assert_raise(ArgumentError) { Account.build_search(:order_by => ["name", "unknown_column"]) }
      assert_nothing_raised { Account.build_search!(:order_by => ["name", "unknown_column"]) }
    end
  end
end