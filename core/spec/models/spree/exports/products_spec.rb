require 'spec_helper'

RSpec.describe Spree::Exports::Products, type: :model do
  let(:store) { create(:store) }
  let(:export) { described_class.new(store: store) }

  describe '#scope' do
    let!(:archived_product) { create(:product, status: 'archived', stores: [store]) }
    let!(:test_product) { create(:product, name: 'test', stores: [store]) }

    context 'when search_params is nil' do
      it 'excludes archived products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).not_to include(archived_product)
      end
    end

    context 'when search_params is present' do
      let(:export) { described_class.new(store: store, search_params: { name: 'test' }) }

      it 'includes all products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).to include(archived_product)
      end
    end
  end
end
