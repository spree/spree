require File.dirname(__FILE__) + '/../test_helper'

class ProductRuleTest < Test::Unit::TestCase

  context "instance" do
    setup do
      create_complete_order
      
      @product1, @product2, @product3 = @order.line_items.map{|li| li.variant.product}
      @product4 = Factory(:product)
      @product5 = Factory(:product)

      @product_group_10_to_20  = Factory(:product_group, :product_scopes_attributes => [
        { :name => "price_between", :arguments => [10,20] },
      ])
      @product_group_20_to_30  = Factory(:product_group, :product_scopes_attributes => [
        { :name => "price_between", :arguments => [20,30] },
      ])

      @rule = Promotion::Rules::Product.new
    end
    
    
    context "with no products" do
      should "be eligible for order" do
        assert @rule.eligible?(@order)
      end
    end
    
    context "with no product group and match_policy any" do
      setup { @rule.preferred_match_policy = 'any' }
    
      # 1 product that is in the order and 1 that isn't
      context "with products 1 and 4" do
        setup do
          @rule.products = [@product1, @product4]
        end
        should "be eligible for order" do
          assert @rule.eligible?(@order)
        end
      end
      context "with products 4 and 5" do
        setup do
          @rule.products = [@product4, @product5]
        end
        should "not be eligible for order" do
          assert !@rule.eligible?(@order)
        end
      end
    end
    
    context "with no product group and match_policy all" do
      setup { @rule.preferred_match_policy = 'all' }
    
      # 1 product that is in the order and 1 that isn't
      context "with products 1 and 4" do
        setup do
          @rule.products = [@product1, @product4]
        end
        should "not be eligible for order" do
          assert ! @rule.eligible?(@order)
        end
      end
      context "with products 1 and 2" do
        setup do
          @rule.products = [@product1, @product2]
        end
        should "be eligible for order" do
          assert @rule.eligible?(@order)
        end
      end
    end    
    

    context "with product group" do
      
      setup do
        Product.destroy_all
        @product1 = Factory(:product, :price => 12.00, :name => 'Ruby 1')
        @product2 = Factory(:product, :price => 14.00, :name => 'Ruby 2')
        @order = Factory(:order)
        
        @rule.product_group = @product_group_10_to_20
      end

      context "and match policy any" do
        setup { @rule.preferred_match_policy = 'any' }
        
        should "be not be eligible for empty order" do
          assert !@rule.eligible?(@order)
        end
        should "be eligible for order once a product from the rule's group is added" do
          Factory(:line_item, :variant => Factory(:variant, :product => @product1), :order => @order)
          @order.reload
          assert @rule.eligible?(@order)
        end
        
      end

      context "and match policy all" do
        setup { @rule.preferred_match_policy = 'all' }
        
        should "not be eligible until order contains all products in the group" do
          assert !@rule.eligible?(@order)

          Factory(:line_item, :variant => Factory(:variant, :product => @product1), :order => @order)
          @order.reload
          assert !@rule.eligible?(@order)

          Factory(:line_item, :variant => Factory(:variant, :product => @product2), :order => @order)
          @order.reload
          assert @rule.eligible?(@order)
        end
      end
      
    end
    
  end

end