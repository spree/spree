require 'test_helper'

class LineItemsControllerTest < ActionController::TestCase
  context "on DELETE to :destroy" do
    setup do 
      set_current_user
      @order = create_complete_order
      @order_total = @order.total
      @line_item = @order.line_items.first
      delete :destroy, :order_id => @order.id, :id => @line_item.id
    end
    
    should_redirect_to("edit order page") { edit_order_url(@order) }
    should_not_set_the_flash    
    
    should "delete the line item" do
      line_items = @order.line_items.reload
      assert_does_not_contain(line_items, @line_item)
    end
    
    should "update the order totals" do
      assert_not_equal @order_total, @order.reload.total
    end
  end
  
end