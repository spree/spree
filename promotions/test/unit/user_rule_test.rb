require File.dirname(__FILE__) + '/../test_helper'

class ItemTotalRuleTest < Test::Unit::TestCase

  context "instance" do
    setup do
      @rule = Promotion::Rules::User.new
      @user1 = Factory(:user)
      @user2 = Factory(:user)
      @user3 = Factory(:user)
    end
    
    context "with user1" do
      setup do
        @rule.users = [@user1]
      end
      should "not be eligible for order with no user" do
        @order = MockOrder.new
        assert ! @rule.eligible?(@order)
      end
      should "be eligible for order with user2" do
        @order = MockOrder.new(:user => @user2)
        assert !@rule.eligible?(@order)
      end
      should "be eligible for order with user1" do
        @order = MockOrder.new(:user => @user1)
        assert @rule.eligible?(@order)
      end
    end

    context "with user1 and user 2" do
      setup do
        @rule.users = [@user1, @user2]
      end
      should "be eligible for order with user1" do
        @order = MockOrder.new(:user => @user1)
        assert @rule.eligible?(@order)
      end
      should "be eligible for order with user2" do
        @order = MockOrder.new(:user => @user2)
        assert @rule.eligible?(@order)
      end
      should "not be eligible for order with user3" do
        @order = MockOrder.new(:user => @user3)
        assert !@rule.eligible?(@order)
      end
    end

  end
  
end