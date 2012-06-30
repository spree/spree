require 'spec_helper'

describe "Order's state machine default" do
  let!(:order) { Factory(:order) }
  before do
    order.stub(:has_available_shipment)
    order.stub(:has_available_payment)
  end

  def should_transition_to(state)
    p order.next!
    p order.errors
    order.state.to_s.should == state.to_s
  end

  context "from cart" do
    before { order.state = 'cart' }

    it "transitions to address" do
      should_transition_to(:address)
    end
  end

  context "from address" do
    before { order.state = 'address' }

    it "transitions to delivery" do
      should_transition_to(:delivery)
    end
  end

  context "from delivery" do
    before { order.state = 'delivery' }

    context "with payment required" do
      before { order.stub(:payment_required? => true) }
      it "transitions to payment" do
        should_transition_to(:payment)
      end
    end

    context "without payment required" do
      before { order.stub(:payment_required? => false) }
      it "transitions to complete" do
        should_transition_to(:complete)
      end
    end
    end

    context "from payment" do
      before { order.state = 'payment' }

      context "with confirmation required" do
        before { order.stub(:confirmation_required? => true) }
        it "transitions to confirmation" do
          should_transition_to(:confirm)
        end
      end

      context "without confirmation required" do
        before { order.stub(:confirmation_required? => false) }
        it "transitions to complete" do
          should_transition_to(:complete)
        end
      end

  end
end
