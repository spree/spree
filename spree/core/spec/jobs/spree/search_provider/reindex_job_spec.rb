require 'spec_helper'

RSpec.describe Spree::SearchProvider::ReindexJob, type: :job do
  let(:store) { @default_store }

  describe '#perform' do
    it 'reindexes the store products in place' do
      provider = instance_double(Spree::SearchProvider::Database)
      allow(Spree::SearchProvider::Database).to receive(:new).with(store).and_return(provider)
      expect(provider).to receive(:reindex).with(satisfy { |scope| scope.to_sql == store.products.to_sql })

      described_class.new.perform(store.id.to_s)
    end

    it 'does nothing if store is not found' do
      expect { described_class.new.perform('0') }.not_to raise_error
    end
  end
end
