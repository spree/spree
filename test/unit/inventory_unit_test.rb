require 'test_helper'

class InventoryUnitTest < ActiveSupport::TestCase
  context InventoryUnit do
    context "when sold" do
      setup do
        line_item = Factory(:line_item, :quantity => 5)
        @order = line_item.order.reload
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

      context "and line_item quantity is increased" do
        setup do
          @line_item = @order.line_items[0]
          @line_item.update_attribute(:quantity, @line_item.quantity + 1)
          InventoryUnit.adjust_units(@order)
        end

        should_change("InventoryUnit.count", :from => 5, :to => 6) { InventoryUnit.count }
      end

      context "and line_item quantity is decreased" do
        setup do
          @line_item = @order.line_items[0]
          @line_item.update_attribute(:quantity, @line_item.quantity - 1)
          InventoryUnit.adjust_units(@order)
        end

        should_change("InventoryUnit.count", :from => 5, :to => 4) { InventoryUnit.count }
      end

      context "and a line_item is destroyed" do
        setup do
          @line_item = @order.line_items[0].destroy
          @line_item.destroy
          InventoryUnit.adjust_units(@order.reload)
        end

        should_change("InventoryUnit.count", :from => 5, :to => 0) { InventoryUnit.count }
      end
    end
  end
end
