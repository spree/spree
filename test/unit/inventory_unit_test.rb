require 'test_helper'

class InventoryUnitTest < ActiveSupport::TestCase
  context InventoryUnit do
    setup do
      @inventory_unit = Factory(:inventory_unit, :state => "on_hand")
      InventoryUnit.stub!(:retrieve_on_hand, :return => [@inventory_unit])
      line_item = Factory(:line_item)
      @order = line_item.order.reload 
    end
    context "when sold" do
      setup { InventoryUnit.sell_units(@order) }
      should "associate the inventory units with the order" do
        assert_equal @order, @inventory_unit.order
      end
    end
  end   
end