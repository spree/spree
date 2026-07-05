require 'spec_helper'

RSpec.describe Spree::SearchProvider::IndexJob, type: :job do
  let(:store) { @default_store }
  let(:product) { create(:product) }

  describe '#perform' do
    it 'calls index on the search provider' do
      provider = instance_double(Spree::SearchProvider::Database)
      allow(Spree::SearchProvider::Database).to receive(:new).with(store).and_return(provider)
      expect(provider).to receive(:index).with(product)

      described_class.new.perform('Spree::Product', product.id.to_s, store.id.to_s)
    end

    it 'does nothing if product is not found' do
      expect {
        described_class.new.perform('Spree::Product', '0', store.id.to_s)
      }.not_to raise_error
    end

    it 'does nothing if store is not found' do
      expect {
        described_class.new.perform('Spree::Product', product.id.to_s, '0')
      }.not_to raise_error
    end
  end
end
