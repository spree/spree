# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PaymentSerializer do
  let(:order) { create(:order_with_line_items) }
  let(:payment_method) { create(:credit_card_payment_method) }
  let(:payment) do
    create(:payment,
           order: order,
           payment_method: payment_method,
           amount: 100.00,
           state: 'completed')
  end

  subject { described_class.serialize(payment) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(payment.prefixed_id)
      expect(subject[:number]).to eq(payment.number)
    end

    it 'includes state as string' do
      expect(subject[:state]).to eq('completed')
    end

    it 'includes amount' do
      expect(subject[:amount]).to eq(100.00)
    end

    it 'includes foreign keys' do
      expect(subject[:order_id]).to eq(order.prefixed_id)
      expect(subject[:payment_method_id]).to eq(payment_method.prefixed_id)
    end

    it 'includes source polymorphic reference' do
      expect(subject).to have_key(:source_type)
      expect(subject).to have_key(:source_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include associations' do
      expect(subject).not_to have_key(:refunds)
      expect(subject).not_to have_key(:log_entries)
    end
  end
end
