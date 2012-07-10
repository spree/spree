require 'spec_helper'

describe Spree::Order do
  let(:order) { Spree::Order.new }
  context "with default state machine" do
    it "has the following transitions" do
      transitions = [
        { :address => :delivery },
        { :delivery => :payment },
        { :payment => :confirm },
        { :confirm => :complete },
        { :payment => :complete },
        { :delivery => :complete }
      ]
      transitions.each do |transition|
        transition = Spree::Order.find_transition(:from => transition.keys.first, :to => transition.values.first)
        transition.should_not be_nil
      end
    end

    it "does not have a transition from delivery to confirm" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    context "#checkout_steps" do
      context "when confirmation not required" do
        before do
          order.stub :confirmation_required? => false
          order.stub :payment_required? => true
        end

        specify do
          order.checkout_steps.should == %w(address delivery payment complete).map(&:to_sym)
        end
      end

      context "when confirmation required" do
        before do
          order.stub :confirmation_required? => true
          order.stub :payment_required? => true
        end

        specify do
          order.checkout_steps.should == %w(address delivery payment confirm complete).map(&:to_sym)
        end
      end

      context "when payment not required" do
        before { order.stub :payment_required? => false }
        specify do
          order.checkout_steps.should == %w(address delivery complete).map(&:to_sym)
        end
      end

      context "when payment required" do
        before { order.stub :payment_required? => true }
        specify do
          order.checkout_steps.should == %w(address delivery payment complete).map(&:to_sym)
        end
      end
    end

    it "starts out at cart" do
      order.state.should == "cart"
    end

    it "transitions to address" do
      order.next!
      order.state.should == "address"
    end

    context "from address" do
      before do
        order.state = 'address'
      end

      it "transitions to delivery" do
        order.stub(:has_available_payment)
        order.next!
        order.state.should == "delivery"
      end
    end

    context "from delivery" do
      before do
        order.state = 'delivery'
      end

      context "with payment required" do
        before do
          order.stub :payment_required? => true
        end

        it "transitions to payment" do
          order.next!
          order.state.should == 'payment'
        end
      end

      context "without payment required" do
        before do
          order.stub :payment_required? => false
        end

        it "transitions to complete" do
          order.next!
          order.state.should == "complete"
        end
      end
    end

    context "from payment" do
      before do
        order.state = 'payment'
      end

      context "with confirmation required" do
        before do
          order.stub :confirmation_required? => true
        end

        it "transitions to confirm" do
          order.next!
          order.state.should == "confirm"
        end
      end

      context "without confirmation required" do
        before do
          order.stub :confirmation_required? => false
        end

        it "transitions to complete" do
          order.next!
          order.state.should == "complete"
        end
      end
    end
  end
end
