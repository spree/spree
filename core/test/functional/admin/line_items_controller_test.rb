require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class Admin::LineItemsControllerTest < ActionController::TestCase
  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      @order = Factory(:order)
      @order.checkout.shipping_method = Factory(:shipping_method)
      #@order.checkout.save
      #@order.shipment.reload
      @variant = Factory(:variant)
    end
  
    context "on POST to :create" do
      setup do
        post :create, { "order_id" => @order.number, "line_item" => { "quantity" => 3, "variant_id" => @variant.id} }
        #@order.reload
      end
  
      should_assign_to :order
      should_respond_with :success
  
      should_change("Order.line_items.size", :by => 1) { @order.line_items.size }
  
      should_change("@order.total", :by => (19.99 * 3)) { @order.item_total.to_f }
  
      should "render a form" do
        assert_select "form[id='edit_order_#{@order.id}']" do
          @order.reload.line_items.each do |line_item|
            assert_select "tr[id='line_item_#{line_item.id}']"
          end
  
        end
      end
  
    end
  
    context "with existing line_item" do
      setup do
        @line_item = Factory(:line_item, :variant => @variant, :order => @order, :price => 19.99, :quantity => 3)
        @order.line_items.reload
        @order.update_totals
      end
  
      context "on POST to :create" do
        setup do
          post :create, {
               "order_id" => @order.number,
               "line_item" => { "quantity" => 3,
                                 "variant_id" => @variant.id}
          }
          @order.reload
        end
  
        should_assign_to :order
        should_respond_with :success
  
        should_not_change("Order.line_items.size") { @order.line_items.size }
  
        should_change("@order.line_items.total", :by => (19.99 * 3)) { @order.line_items.total.to_f }
        should_change("@order.total", :by => (19.99 * 3)) { @order.item_total.to_f }
  
        should "render a form" do
          assert_select "form[id='edit_order_#{@order.id}']" do
            @order.reload.line_items.each do |line_item|
              assert_select "tr[id='line_item_#{line_item.id}']"
            end
  
          end
        end
  
      end
  
      context "on PUT to :update with quantity = 2" do
        setup do
          put :update, {
            "id" => @line_item.id,
            "order_id" => @order.number,
            "line_item" => {
              "quantity" => 2}
          }
  
          @order.line_items.reload
          @order.update_totals
          @order.reload
        end
  
        should_assign_to :order
        should_assign_to :line_item
        should_respond_with :success
  
        should_not_change("Order.line_items.size") { @order.line_items.size }
  
        should_change("@order.line_items.total", :to => (19.99 * 2)) { @order.line_items.total.to_f }
        should_change("@order.total", :to => (19.99 * 2)) { @order.total.to_f }
  
        should "render a form" do
          assert_select "form[id='edit_order_#{@order.id}']" do
            @order.reload.line_items.each do |line_item|
              assert_select "tr[id='line_item_#{line_item.id}']"
            end
  
          end
        end
      end
  
      context "on PUT to :update with quantity = 0" do
        setup do
          put :update, {
            "id" => @line_item.id,
            "order_id" => @order.number,
            "line_item" => {
              "quantity" => 0}
          }
  
          @order.line_items.reload
          @order.update_totals
        end
  
        should_assign_to :order
        should_assign_to :line_item
        should_respond_with :success
  
        should_change("Order.line_items.size", :by => -1) { @order.line_items.size }
  
        should_change("@order.line_items.total", :by => (19.99 * -3)) { @order.line_items.total.to_f }
        should_change("@order.total", :by => (19.99 * -3)) { @order.total.to_f }
  
        should "render a form" do
          assert_select "form[id='edit_order_#{@order.id}']" do
            @order.reload.line_items.each do |line_item|
              assert_select "tr[id='line_item_#{line_item.id}']"
            end
  
          end
        end
      end
  
      context "on DELETE to :destroy" do
        setup do
          delete :destroy, {
            "id" => @line_item.id,
            "order_id" => @order.number
          }
  
          @order.line_items.reload
          @order.update_totals
  
          should_assign_to :order
          should_assign_to :line_item
          should_respond_with :success
  
          should_change("Order.line_items.size", :by => -1) { @order.line_items.size }
  
          should_change("@order.line_items.total", :by => (19.99 * -3)) { @order.line_items.total.to_f }
          should_change("@order.total", :by => (19.99 * -3)) { @order.total.to_f }
  
          should "render a form" do
            assert_select "form[id='edit_order_#{@order.id}']" do
              @order.reload.line_items.each do |line_item|
                assert_select "tr[id='line_item_#{line_item.id}']"
              end
  
            end
          end
        end
      end
  
    end
  
  end
  
  context "given a paid order" do
    setup do
      #Spree::Config.set(:auto_capture => true)
      UserSession.create(Factory(:admin_user))
      @variant = Factory(:variant)
      create_paid_order
      @order.reload
    end
    context "with existing line_item" do
      setup do
        @order.line_items.destroy_all
        @order.adjustments.destroy_all
        @line_item = Factory(:line_item, :variant => @variant, :order => @order, :price => 10.00, :quantity => 1)
        @order.payments.first.update_attribute(:amount, 10.00)
        @order.line_items.reload
        @order.update_totals
      end
      context "on PUT to :update with quantity = 4" do
        setup do
          put :update, {
            "id" => @line_item.id,
            "order_id" => @order.number,
            "line_item" => {
              "quantity" => 2}
          }

          @order.line_items.reload
          @order.reload
        end
        should "update the order total" do
          assert equal 20.0, @order.total.to_f
        end
        should "change order state to balance_due" do
          assert @order.balance_due?
        end
      end
    end
  end
  
end
