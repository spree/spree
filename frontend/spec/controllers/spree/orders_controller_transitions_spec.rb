require 'spec_helper'

Spree::Order.class_eval do
  attr_accessor :did_transition
end

module Spree
  describe OrdersController do
    # Regression test for #2004
    context "with a transition callback on first state" do
      let(:order) { Spree::Order.new }

      before do
        controller.stub :current_order => order
        controller.should_receive(:authorize!).at_least(:once).and_return(true)

        first_state, _ = Spree::Order.checkout_steps.first
        Spree::Order.state_machine.after_transition :to => first_state do |order|
          order.did_transition = true
        end
      end

      it "correctly calls the transition callback" do
        order.did_transition.should be_nil
        params = {
          # The submit button. Checked, and if it's present will do the transition
          :checkout => "checkout",
          :order => { :email => "foo@bar.com" }
        }
        spree_put :update, params, { :order_id => 1}
        order.did_transition.should be_true
      end
    end
  end
end
