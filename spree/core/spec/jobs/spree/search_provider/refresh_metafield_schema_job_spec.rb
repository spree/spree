# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SearchProvider::RefreshMetafieldSchemaJob do
  describe '#perform' do
    it 'clears the metafield attributes cache so the next registry read is from the DB' do
      Spree::SearchProvider::MetafieldAttributes.clear_cache!
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'x')
      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).to include('mf_6_custom_x')

      allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Database')

      described_class.perform_now

      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'y')
      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).
        to include('mf_6_custom_x', 'mf_6_custom_y')
    end

    it 'refreshes Meilisearch index settings for every store' do
      store1 = Spree::Store.default
      store2 = create(:store)
      provider1 = instance_double(Spree::SearchProvider::Meilisearch)
      provider2 = instance_double(Spree::SearchProvider::Meilisearch)

      allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Meilisearch')
      allow(Spree::SearchProvider::Meilisearch).to receive(:indexing_required?).and_return(true)
      allow(Spree::SearchProvider::Meilisearch).to receive(:new).with(store1).and_return(provider1)
      allow(Spree::SearchProvider::Meilisearch).to receive(:new).with(store2).and_return(provider2)
      allow(Spree::Store).to receive(:find_each).and_yield(store1).and_yield(store2)

      expect(provider1).to receive(:ensure_index_settings!)
      expect(provider2).to receive(:ensure_index_settings!)

      described_class.perform_now
    end

    it 'skips store iteration when the provider does not require indexing' do
      allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Database')
      expect(Spree::SearchProvider::Database).not_to receive(:new)

      described_class.perform_now
    end
  end
end
