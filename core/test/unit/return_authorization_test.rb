require 'test_helper.rb'

class ReturnAuthorizationTest < ActiveSupport::TestCase
  fixtures :payment_methods
  should "be authorized initially" do
    assert ReturnAuthorization.new.authorized?
  end

  context "ReturnAuthorization" do
    setup do
      @order = Order.create!
      @order.line_items << [Factory(:line_item, :order=>@order),Factory(:line_item, :order=>@order)]

      #complete order / checkout
      @order.complete!
      @order.payments.create!(:amount => @order.total, :payment_method => Gateway.current)

      #@order.pay!
      @order.update_attribute(:state, 'paid')

      @order.reload
      @order.shipment.reload #hack for the @order.shipment caching

      @line_item = @order.line_items.first
      @return_authorization = ReturnAuthorization.new(:order => @order, :amount => @line_item.total)
    end

    context "with an order that has no shipped units" do
      should "not be valid" do
        assert !@return_authorization.valid?
        assert_not_nil @return_authorization.errors[:order]
      end
    end

    context "with an order that has shipped units" do
      setup do
        @return_authorization.order.shipment.ship!
        @return_authorization.order.reload
      end

      should "be valid" do
        assert @return_authorization.valid?
        assert_nil @return_authorization.errors[:order]
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
