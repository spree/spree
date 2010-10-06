require File.dirname(__FILE__) + '/../test_helper'

class ProductPromotionsTest < Test::Unit::TestCase

  context "possible_promotions" do
    setup do
      ProductGroup.destroy_all

      @under_50_product_group  = Factory(:product_group, :name => 'under 50', :product_scopes_attributes => [
        { :name => "master_price_lte", :arguments => 50 },
      ])
      @ruby_product_group  = Factory(:product_group, :name => 'ruby stuff', :product_scopes_attributes => [
        { :name => "in_name", :arguments => "ruby" },
      ])
      
      # in neither group
      @product1 = Factory(:product, :name => 'test product 1', :price => 60.00)
      @product2 = Factory(:product, :name => 'test product 2', :price => 60.00)
      # should be in the group for under $50
      @product3 = Factory(:product, :name => 'test product 3', :price => 40.00)
      # in group for products with ruby in the name
      @product4 = Factory(:product, :name => 'test ruby product 1', :price => 60.00)

      @promotion1 = Factory(:promotion, :description => "promotion for products between $10 and $20")
      Promotion::Rules::Product.create(:promotion => @promotion1, :product_group => @under_50_product_group)
      
      @promotion2 = Factory(:promotion, :description => "promotion for products between $10 and $20")
      Promotion::Rules::Product.create(:promotion => @promotion2, :products => [@product2])
      
    end
    
    context "for product not in any groups or assigned to any product promotion rule" do
      should "be empty" do
        assert @product1.possible_promotions.empty?
      end
    end

    context "for product that matches a group" do
      should "include the promotion using that group" do
        assert @product3.possible_promotions.include?(@promotion1)
      end
    end

    context "for product that is assigned to a promotion rule" do
      should "include the promotion it's assigned to" do
        assert @product2.possible_promotions.include?(@promotion2)
      end
    end
    
  end
  
end