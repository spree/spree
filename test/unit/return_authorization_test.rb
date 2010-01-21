require 'test_helper'

class ReturnAuthorizationTest < ActiveSupport::TestCase
  context "ReturnAuthorization" do
    setup do
      create_complete_order

      #complete order / checkout
      add_capturable_card(@order)
      3.times { @order.checkout.next! }
      @order.reload
      @creditcard.capture(@creditcard.authorization)

      #force shipment to ready_to_ship
      shipment = @order.shipment
      shipment.ready!

      @order.reload
      
      @line_item = @order.line_items.first
      @return_authorization = ReturnAuthorization.create(:order => @order, :amount => @line_item.total)
    end

    should "be authorized initally" do
      assert ReturnAuthorization.new.authorized?
    end

    context "with an order that has no shipped units" do
      should "not be valid" do
        assert !@return_authorization.valid?
        assert_not_nil @return_authorization.errors.on(:order)
      end
    end

    context "with an order that has shipped units" do
      setup do
        @return_authorization.order.shipment.order.reload

        @shipment = @return_authorization.order.shipment

        @return_authorization.order.shipment.ship!
        @return_authorization.order.reload
      end

      should "be valid" do
        assert @return_authorization.valid?
        assert_nil @return_authorization.errors.on(:order)
      end
    
      context "with no inventory_units" do
        should "not be receivable" do
          assert !@return_authorization.can_receive?
        end
      end
    
      context "with inventory_units" do
        setup do
          @return_authorization.add_variant(@line_item.variant_id, @line_item.quantity)
          @return_authorization.inventory_units.reload
        end
      
        should "be receivable" do
          assert @return_authorization.can_receive?
        end
      
        should "increase inventory_units.size" do
          assert_equal @line_item.quantity, @return_authorization.inventory_units.size
        end
      
        should "decrease order.returnable_units count for returned variant" do
          assert_equal nil, @return_authorization.order.returnable_units[@line_item.variant]
        end
      
        should "change order state to awaiting_return" do
          assert_equal "awaiting_return", @return_authorization.order.state
        end
      
        context "that have been recieved" do
          setup do
            ::ReturnAuthorizationCredit
            @return_authorization.receive!
            @return_authorization.order.reload
          end
      
          should_change("@return_authorization.order.adjustments.size", :by => 1) { @return_authorization.order.adjustments.size }
          should_change("@return_authorization.order.credits.size", :by => 1) { @return_authorization.order.credits.size }
      
          should "change state to received" do
            assert @return_authorization.received?
          end
      
          should "change order state to credit_owed" do
            assert @return_authorization.order.credit_owed?
          end
        end
      end
    
    end

  end

end
