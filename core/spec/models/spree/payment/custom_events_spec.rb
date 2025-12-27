# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Payment::CustomEvents do
  let(:order) { create(:order_with_line_items) }
  let(:payment) { create(:payment, order: order, state: 'pending') }

  before do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)
  end

  describe 'payment.paid event' do
    it 'publishes payment.paid when payment state changes to completed' do
      allow(order).to receive(:paid?).and_return(false)

      payment.update!(state: 'completed')

      expect(Spree::Events).to have_received(:publish).with('payment.paid', anything, anything)
    end

    it 'does not publish payment.paid when state changes to something other than completed' do
      payment.update!(state: 'processing')

      expect(Spree::Events).not_to have_received(:publish).with('payment.paid', anything, anything)
    end

    it 'does not publish when events are disabled' do
      allow(Spree::Events).to receive(:enabled?).and_return(false)

      payment.update!(state: 'completed')

      expect(Spree::Events).not_to have_received(:publish).with('payment.paid', anything, anything)
    end
  end

  describe 'order.paid event' do
    it 'publishes order.paid when payment completes and order is fully paid' do
      allow(order).to receive(:paid?).and_return(true)

      payment.update!(state: 'completed')

      expect(Spree::Events).to have_received(:publish).with('payment.paid', anything, anything)
      expect(Spree::Events).to have_received(:publish).with('order.paid', anything, anything)
    end

    it 'does not publish order.paid when order still has outstanding balance' do
      allow(order).to receive(:paid?).and_return(false)

      payment.update!(state: 'completed')

      expect(Spree::Events).to have_received(:publish).with('payment.paid', anything, anything)
      expect(Spree::Events).not_to have_received(:publish).with('order.paid', anything, anything)
    end
  end
end
