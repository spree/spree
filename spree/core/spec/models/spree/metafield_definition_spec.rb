require 'spec_helper'

RSpec.describe Spree::MetafieldDefinition, type: :model do
  let(:metafield_definition) { build(:metafield_definition) }

  describe 'scopes' do
    let!(:both_definition) { create(:metafield_definition, display_on: 'both') }
    let!(:front_end_definition) { create(:metafield_definition, :front_end_only) }
    let!(:back_end_definition) { create(:metafield_definition, :back_end_only) }
    let!(:product_definition) { create(:metafield_definition, resource_type: 'Spree::Product') }
    let!(:variant_definition) { create(:metafield_definition, :for_variant) }
    let!(:searchable_definition) { create(:metafield_definition, :searchable, key: 'searchable_field') }
    let!(:sortable_definition) { create(:metafield_definition, :sortable, key: 'sortable_field') }

    describe '.available' do
      it 'returns only both definitions (from DisplayOn concern)' do
        expect(described_class.available).to include(both_definition)
        expect(described_class.available).not_to include(front_end_definition)
        expect(described_class.available).not_to include(back_end_definition)
      end
    end

    describe '.available_on_front_end' do
      it 'returns public definitions (front_end and both)' do
        expect(described_class.available_on_front_end).to include(front_end_definition, both_definition)
        expect(described_class.available_on_front_end).not_to include(back_end_definition)
      end
    end

    describe '.available_on_back_end' do
      it 'returns admin definitions (back_end and both)' do
        expect(described_class.available_on_back_end).to include(back_end_definition, both_definition)
        expect(described_class.available_on_back_end).not_to include(front_end_definition)
      end
    end

    describe '.for_resource_type' do
      it 'returns definitions for specific resource type' do
        expect(described_class.for_resource_type('Spree::Product')).to include(product_definition)
        expect(described_class.for_resource_type('Spree::Product')).not_to include(variant_definition)

        expect(described_class.for_resource_type('Spree::Variant')).to include(variant_definition)
        expect(described_class.for_resource_type('Spree::Variant')).not_to include(product_definition)
      end
    end

    describe '.searchable' do
      it 'returns only searchable definitions' do
        expect(described_class.searchable).to include(searchable_definition)
        expect(described_class.searchable).not_to include(product_definition)
      end
    end

    describe '.sortable' do
      it 'returns only sortable definitions' do
        expect(described_class.sortable).to include(sortable_definition)
        expect(described_class.sortable).not_to include(product_definition)
      end
    end
  end

  describe 'searchable / sortable validations' do
    it 'allows searchable on short_text' do
      definition = build(:metafield_definition, :short_text_field, searchable: true)
      expect(definition).to be_valid
    end

    it 'allows searchable on long_text' do
      definition = build(:metafield_definition, :long_text_field, searchable: true)
      expect(definition).to be_valid
    end

    it 'rejects searchable on rich_text' do
      definition = build(:metafield_definition, :rich_text_field, searchable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable].first).to include('short text', 'long text', 'number')
    end

    it 'rejects searchable on boolean' do
      definition = build(:metafield_definition, :boolean_field, searchable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable]).to be_present
    end

    it 'allows sortable on short_text and number' do
      expect(build(:metafield_definition, :short_text_field, sortable: true)).to be_valid
      expect(build(:metafield_definition, :number_field, sortable: true)).to be_valid
    end

    it 'rejects sortable on long_text' do
      definition = build(:metafield_definition, :long_text_field, sortable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:sortable].first).to include('short text', 'number')
      expect(definition.errors[:sortable].first).not_to include('long text')
    end

    it 'rejects changing metafield_type to a non-searchable class while searchable stays true' do
      definition = create(:metafield_definition, :short_text_field, searchable: true)
      definition.field_type = 'boolean'
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable]).to be_present
    end

    it 'rejects changing metafield_type to a non-sortable class while sortable stays true' do
      definition = create(:metafield_definition, :short_text_field, sortable: true)
      definition.field_type = 'long_text'
      expect(definition).not_to be_valid
      expect(definition.errors[:sortable]).to be_present
    end
  end

  describe '.searchable_field_type_tokens / .sortable_field_type_tokens' do
    it 'derives tokens from metafield type class capabilities' do
      expect(described_class.searchable_field_type_tokens).to match_array(%w[short_text long_text number])
      expect(described_class.sortable_field_type_tokens).to match_array(%w[short_text number])
    end
  end

  describe '#search_key' do
    it 'returns the SearchProvider attribute key with a length-prefixed namespace' do
      metafield_definition = build(:metafield_definition, namespace: 'custom', key: 'material')
      expect(metafield_definition.search_key).to eq('mf_6_custom_material')
    end

    it 'produces distinct keys when namespace/key underscore boundaries differ' do
      left = build(:metafield_definition, namespace: 'a_b', key: 'c')
      right = build(:metafield_definition, namespace: 'a', key: 'b_c')

      expect(left.search_key).to eq('mf_3_a_b_c')
      expect(right.search_key).to eq('mf_1_a_b_c')
      expect(left.search_key).not_to eq(right.search_key)
    end
  end

  describe 'Ransack allowlist' do
    it 'allows filtering by searchable and sortable' do
      matching = create(:metafield_definition, :short_text_field, :searchable, :sortable, key: 'ransack_match')
      create(:metafield_definition, :short_text_field, key: 'ransack_other')

      result = described_class.ransack(searchable_eq: true, sortable_eq: true).result
      expect(result).to include(matching)
      expect(result.map(&:key)).not_to include('ransack_other')
    end
  end

  describe '#csv_header_name' do
    it 'returns the CSV header name with metafield prefix' do
      metafield_definition = build(:metafield_definition, namespace: 'custom', key: 'field1')
      expect(metafield_definition.csv_header_name).to eq('metafield.custom.field1')
    end
  end

  describe '#full_key' do
    it 'returns the full key with namespace' do
      metafield_definition = build(:metafield_definition, namespace: 'custom', key: 'field1')
      expect(metafield_definition.full_key).to eq('custom.field1')
    end
  end

  describe 'search schema refresh' do
    context 'when the search provider requires indexing' do
      before do
        allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Meilisearch')
        allow(Spree::SearchProvider::Meilisearch).to receive(:indexing_required?).and_return(true)
      end

      it 'enqueues a schema refresh job when a searchable definition is created' do
        expect {
          create(:metafield_definition, :short_text_field, :searchable, key: 'schema_refresh_field')
        }.to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
      end

      it 'enqueues when searchable is toggled on an existing definition' do
        definition = create(:metafield_definition, :short_text_field, key: 'toggle_search')

        expect {
          definition.update!(searchable: true)
        }.to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
      end

      it 'enqueues a schema refresh job when a searchable definition is destroyed' do
        definition = create(:metafield_definition, :short_text_field, :searchable, key: 'destroy_refresh')

        expect {
          definition.destroy!
        }.to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
      end

      it 'does not enqueue on destroy when the definition was not searchable or sortable' do
        definition = create(:metafield_definition, :short_text_field, key: 'plain_destroy')

        expect {
          definition.destroy!
        }.not_to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
      end
    end

    it 'does not enqueue a job when the provider does not require indexing' do
      allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Database')

      expect {
        create(:metafield_definition, :short_text_field, :searchable, key: 'db_only_refresh')
      }.not_to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
    end

    it 'does not enqueue when only the label changes' do
      definition = create(:metafield_definition, :short_text_field, key: 'label_only')

      expect {
        definition.update!(name: 'Renamed label')
      }.not_to have_enqueued_job(Spree::SearchProvider::RefreshMetafieldSchemaJob)
    end

    it 'clears the metafield attributes cache immediately on a relevant change' do
      Spree::SearchProvider::MetafieldAttributes.clear_cache!
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'cached')
      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).to include('mf_6_custom_cached')

      expect(Spree::Dependencies.search_metafield_attributes_class).to receive(:clear_cache!).and_call_original

      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'after')
      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).to include('mf_6_custom_cached', 'mf_6_custom_after')
    end

    it 'clears the registry when a searchable/sortable definition is destroyed' do
      Spree::SearchProvider::MetafieldAttributes.clear_cache!
      definition = create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'to_delete')
      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).to include('mf_6_custom_to_delete')

      expect(Spree::Dependencies.search_metafield_attributes_class).to receive(:clear_cache!).and_call_original

      definition.destroy!

      expect(Spree::SearchProvider::MetafieldAttributes.sortable_attribute_keys).not_to include('mf_6_custom_to_delete')
    end
  end
end
