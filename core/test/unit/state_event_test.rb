require 'test_helper'

class StateEventTest < ActiveSupport::TestCase
  fixtures :payment_methods
  
  context "Order" do
    setup do
      @order = Factory(:order_with_totals)
    end

    context "when completed" do
      setup { @order.complete! }
      should_change("StateEvent.count", :by => 1) { StateEvent.count }
      should_change("@order.state", :from => "in_progress", :to => "new") { @order.state }

      context "then canceled" do
        setup { @order.cancel! }
        should_change("StateEvent.count", :by => 1) { StateEvent.count }
        should_change("@order.state", :from => "new", :to => "canceled") { @order.state }

        should "allow resuming" do
          assert @order.can_resume?, "Order can't be resumed(and it should!)"
        end

        context "then resumed" do
          setup { @order.resume! }

          should_change("StateEvent.count", :by => 1) { StateEvent.count }
          should_change("@order.state", :from => "canceled", :to => "new") { @order.state }
        end
      end
    end
  end

  context "Shipment" do
    setup do
      @shipment = Factory.create(:shipment)
    end

    context "when completed" do
      setup { @shipment.ready! }

      should "create a state event with the correct stateful" do
        assert_equal 1, @shipment.state_events.count
        assert_equal @shipment, @shipment.state_events.first.stateful
      end
    end

  end

end
