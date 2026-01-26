require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => product.prefix_id,
        'name' => product.name,
        'slug' => product.slug
      )
    end

    it 'includes timestamps' do
      expect(subject).to have_key('created_at')
      expect(subject).to have_key('updated_at')
    end

    it 'does not include admin-only attributes' do
      expect(subject).not_to have_key('cost_price')
      expect(subject).not_to have_key('cost_currency')
      expect(subject).not_to have_key('private_metadata')
      expect(subject).not_to have_key('deleted_at')
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => product.prefix_id,
        'name' => product.name,
        'slug' => product.slug
      )
    end

    it 'includes admin-only attributes' do
      expect(subject).to have_key('cost_price')
      expect(subject).to have_key('cost_currency')
      expect(subject).to have_key('deleted_at')
    end
  end
end
