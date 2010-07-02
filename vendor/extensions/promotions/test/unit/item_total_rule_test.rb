require File.dirname(__FILE__) + '/../test_helper'

class ItemTotalRuleTest < Test::Unit::TestCase

  context "instance" do
    setup do
      @order_199 = MockOrder.new(:item_total => 199.00)
      @order_200 = MockOrder.new(:item_total => 200.00)
      @order_201 = MockOrder.new(:item_total => 201.00)
      
      def @order_200.item_total
        200.00
      end
      
      @rule = Promotion::Rules::ItemTotal.new
      @rule.preferred_amount = 200
    end
    
    context "with greater than operator" do
      setup do
        @rule.preferred_operator = 'gt'
      end
      should "not be eligible for order with item total of 200" do
        assert ! @rule.eligible?(@order_200)
      end
      should "be eligible for order with item total of 201" do
        assert @rule.eligible?(@order_201)
      end
    end
    
    context "with greater than or equal to operator" do
      setup do
        @rule.preferred_operator = 'gte'
      end
      should "not be eligible for order with item total of 199" do
        assert ! @rule.eligible?(@order_199)
      end
      should "be eligible for order with item total of 200" do
        assert @rule.eligible?(@order_200)
      end
      should "be eligible for order with item total of 201" do
        assert @rule.eligible?(@order_201)
      end
    end

  end
  
end