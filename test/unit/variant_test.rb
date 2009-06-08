require 'test_helper'

class VariantTest < Test::Unit::TestCase

  context "Variant.create" do
    setup { @product = Factory.create(:product, :master_price => 10.99, :variants => [] ) }
    context "with price specified" do
      setup do
        @variant = Variant.create(:product => @product, :price => 11.33)
      end
      should "ignore the product's master price" do
        assert_in_delta @variant.price, 11.33, 0.00001
      end
      should_not_change "InventoryUnit.count"
    end
    context "with no price specified" do
      setup do 
        @variant = Variant.create(:product => @product)
      end
      should "use the prodcut's master price" do
        assert_in_delta @variant.price, 10.99, 0.00001
      end
      should_not_change "InventoryUnit.count"
    end
    context "with specified inventory level" do
      setup do 
        @variant = Variant.create(:product => @product, :on_hand => "3")
      end
      should_change "InventoryUnit.count", :by => 3
    end
  end
  context "Variant instance with 1 unit of inventory" do
    setup do
      @variant = Factory(:variant, :inventory_units => [Factory(:inventory_unit)])
    end
    should "return true for in_stock" do
      assert @variant.in_stock
    end
    context "when on_hand is increased" do
      setup { @variant.update_attribute("on_hand", "5") }
      should_change "InventoryUnit.count", :by => 4
      should "return correct amount for on_hand" do
        assert_equal 5, @variant.on_hand
      end
    end
    context "when on_hand is changed to 0" do
      setup do 
        @variant.update_attribute("on_hand", "0")
      end
      should_change "InventoryUnit.count", :by => -1
      should "return correct amount for on_hand" do
        assert_equal 0, @variant.on_hand
      end
      should "return false for in_stock" do
        assert !@variant.in_stock
      end      
    end
  end
end