require 'spec_helper'

Spree::Order.class_eval do
  attr_accessor :did_transition
end

module Spree
  describe OrdersController, type: :controller do
    # Regression test for #2004
    context 'with a transition callback on first state' do
      let(:order) { Spree::Order.new }

      before do
        allow(controller).to receive_messages current_order: order
        expect(controller).to receive(:authorize!).at_least(:once).and_return(true)

        first_state, = Spree::Order.checkout_steps.first
        Spree::Order.state_machine.after_transition to: first_state do |order|
          order.did_transition = true
        end
      end

      it 'correctly calls the transition callback' do
        expect(order.did_transition).to be_nil
        order.line_items << FactoryBot.create(:line_item)
        spree_put :update, { checkout: 'checkout' }, order_id: 1
        expect(order.did_transition).to be true
      end
    end
  end
end
