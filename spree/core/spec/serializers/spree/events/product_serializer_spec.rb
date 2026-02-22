# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ProductSerializer do
  let(:store) { @default_store }
  let(:product) do
    create(:product,
           name: 'Test Product',
           status: 'active',
           available_on: Time.zone.parse('2024-01-01 00:00:00'),
           stores: [store])
  end

  subject { described_class.serialize(product) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(product.prefixed_id)
      expect(subject[:name]).to eq('Test Product')
      expect(subject[:slug]).to eq(product.slug)
    end

    it 'includes status as string' do
      expect(subject[:status]).to eq('active')
    end

    it 'includes availability timestamps' do
      expect(subject[:available_on]).to eq('2024-01-01T00:00:00Z')
      expect(subject).to have_key(:discontinue_on)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include associations' do
      expect(subject).not_to have_key(:variants)
      expect(subject).not_to have_key(:images)
      expect(subject).not_to have_key(:taxons)
    end
  end
end
