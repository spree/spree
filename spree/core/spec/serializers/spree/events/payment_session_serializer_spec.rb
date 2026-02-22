# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PaymentSessionSerializer do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: 99.99) }

  subject { described_class.serialize(payment_session) }

  describe '#as_json' do
    it 'includes identity and status' do
      expect(subject[:id]).to eq(payment_session.prefixed_id)
      expect(subject[:status]).to eq('pending')
    end

    it 'includes amount fields' do
      expect(subject[:amount]).to eq(99.99.to_d)
      expect(subject[:currency]).to eq('USD')
    end

    it 'includes foreign keys' do
      expect(subject[:order_id]).to eq(order.prefixed_id)
      expect(subject[:payment_method_id]).to eq(payment_method.prefixed_id)
      expect(subject[:external_id]).to be_present
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
