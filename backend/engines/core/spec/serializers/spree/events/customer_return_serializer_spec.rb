# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::CustomerReturnSerializer do
  let(:customer_return) { create(:customer_return) }

  subject { described_class.serialize(customer_return) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(customer_return.prefixed_id)
      expect(subject[:number]).to eq(customer_return.number)
    end

    it 'includes foreign keys' do
      expect(subject[:stock_location_id]).to eq(customer_return.stock_location&.prefixed_id)
      expect(subject).to have_key(:store_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
