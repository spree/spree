# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PriceSerializer do
  let(:variant) { create(:variant) }
  let(:price) { variant.prices.first }

  subject { described_class.serialize(price) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(price.prefix_id)
    end

    it 'includes amount fields' do
      expect(subject[:amount]).to be_present
      expect(subject).to have_key(:compare_at_amount)
      expect(subject[:currency]).to eq(price.currency)
    end

    it 'includes variant_id' do
      expect(subject[:variant_id]).to eq(variant.prefix_id)
    end

    it 'includes deleted_at' do
      expect(subject).to have_key(:deleted_at)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
