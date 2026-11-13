require 'spec_helper'

RSpec.describe Spree::SearchProvider::ConfigureIndexJob, type: :job do
  let(:store) { @default_store }

  describe '#perform' do
    it 'pushes the store index settings' do
      provider = instance_double(Spree::SearchProvider::Database)
      allow(Spree::SearchProvider::Database).to receive(:new).with(store).and_return(provider)
      expect(provider).to receive(:ensure_index_settings!)

      described_class.new.perform(store.id.to_s)
    end

    it 'does nothing if store is not found' do
      expect { described_class.new.perform('0') }.not_to raise_error
    end
  end
end
