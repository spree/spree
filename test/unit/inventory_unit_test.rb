require 'test_helper'

class InventoryUnitTest < ActiveSupport::TestCase
  context InventoryUnit do
    setup do
      line_item = Factory(:line_item, :quantity => 5)
      @order = line_item.order.reload
    end
    context "when sold" do
      setup do
        InventoryUnit.sell_units(@order)
      end

      should_change("InventoryUnit.count", :by => 5) { InventoryUnit.count }
      context "when sold (again - b/c of unexpected error) " do
        setup do 
          @order.state = "in_progress"
          InventoryUnit.sell_units(@order)          
        end
        should_not_change("InventoryUnit.count") { InventoryUnit.count }
      end

    end
  end   
end
