require 'test_helper'

class InventoryUnitTest < ActiveSupport::TestCase
  context InventoryUnit do
    setup do
      line_item = Factory(:line_item)
      @inventory_unit = Factory(:inventory_unit, :state => "on_hand", :variant => line_item.variant)
      @order = line_item.order.reload
    end
    context "when sold" do
      setup do
        InventoryUnit.sell_units(@order)
        @inventory_unit.reload
      end
      should "associate the inventory units with the order" do
        assert_equal @order, @inventory_unit.order
      end
    end
  end   
end
