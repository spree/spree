require 'spec_helper'

RSpec.describe Spree::SearchProvider::RemoveJob, type: :job do
  let(:store) { @default_store }

  describe '#perform' do
    it 'calls remove_by_id on the search provider with prefixed_id' do
      provider = instance_double(Spree::SearchProvider::Database)
      allow(Spree::SearchProvider::Database).to receive(:new).with(store).and_return(provider)
      expect(provider).to receive(:remove_by_id).with('prod_abc')

      described_class.new.perform('prod_abc', store.id.to_s)
    end

    it 'does nothing if store is not found' do
      expect {
        described_class.new.perform('prod_abc', '0')
      }.not_to raise_error
    end
  end
end
