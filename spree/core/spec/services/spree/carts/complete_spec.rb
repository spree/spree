require 'spec_helper'

RSpec.describe Spree::Carts::Complete do
  subject { described_class }

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }

  before do
    order.update_column(:state, 'payment')
    create(:payment, order: order, amount: order.total, state: 'checkout')
    order.shipments.each { |s| s.update_column(:state, 'ready') }
  end

  describe '#call' do
    it 'completes the order' do
      result = subject.call(cart: order)

      expect(result).to be_success
      expect(order.reload.state).to eq('complete')
      expect(order.completed_at).to be_present
    end

    it 'returns the order as value' do
      result = subject.call(cart: order)

      expect(result.value).to eq(order)
    end

    context 'when order is already completed' do
      before { order.update_columns(state: 'complete', completed_at: Time.current) }

      it 'returns success without re-processing' do
        result = subject.call(cart: order)

        expect(result).to be_success
        expect(result.value).to eq(order)
      end
    end

    context 'when order is canceled' do
      before { order.update_column(:state, 'canceled') }

      it 'returns failure' do
        result = subject.call(cart: order)

        expect(result).to be_failure
      end
    end

    context 'when order cannot be completed (missing address)' do
      before { order.update_column(:state, 'cart') }

      let(:order) { create(:order, store: store) }

      it 'returns failure' do
        result = subject.call(cart: order)

        expect(result).to be_failure
      end
    end

    context 'when payments were already processed by the payment session' do
      before do
        order.payments.destroy_all
        create(:payment, order: order, amount: order.total, state: 'completed')
        order.update_column(:payment_total, order.total)
      end

      it 'completes the order without re-processing payments' do
        result = subject.call(cart: order)

        expect(result).to be_success
        expect(order.reload.state).to eq('complete')
        # Payment stays completed — not re-processed
        expect(order.payments.first.state).to eq('completed')
      end
    end

    context 'when payment_total covers order total' do
      before do
        order.update_column(:payment_total, order.total)
      end

      it 'completes the order successfully' do
        result = subject.call(cart: order)

        expect(result).to be_success
        expect(order.reload.state).to eq('complete')
      end
    end

    context 'when order does not require payment' do
      before do
        order.update_column(:total, 0)
      end

      it 'completes without payment processing' do
        result = subject.call(cart: order)

        expect(result).to be_success
      end
    end
  end
end
