require 'spec_helper'

RSpec.describe Spree::CustomFieldDefinition, type: :model do
  let(:custom_field_definition) { build(:custom_field_definition) }

  describe 'scopes' do
    let!(:visible_definition) { create(:custom_field_definition, storefront_visible: true) }
    let!(:admin_only_definition) { create(:custom_field_definition, :admin_only) }
    let!(:product_definition) { create(:custom_field_definition, resource_type: 'Spree::Product') }
    let!(:variant_definition) { create(:custom_field_definition, :for_variant) }
    let!(:searchable_definition) { create(:custom_field_definition, :searchable, key: 'searchable_field') }
    let!(:sortable_definition) { create(:custom_field_definition, :sortable, key: 'sortable_field') }

    describe '.storefront_visible' do
      it 'returns only definitions exposed to the storefront' do
        expect(described_class.storefront_visible).to include(visible_definition)
        expect(described_class.storefront_visible).not_to include(admin_only_definition)
      end
    end

    describe '.admin_only' do
      it 'returns only definitions hidden from the storefront' do
        expect(described_class.admin_only).to include(admin_only_definition)
        expect(described_class.admin_only).not_to include(visible_definition)
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
      definition = build(:custom_field_definition, :short_text_field, searchable: true)
      expect(definition).to be_valid
    end

    it 'allows searchable on long_text' do
      definition = build(:custom_field_definition, :long_text_field, searchable: true)
      expect(definition).to be_valid
    end

    it 'rejects searchable on rich_text' do
      definition = build(:custom_field_definition, :rich_text_field, searchable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable].first).to include('short text', 'long text', 'number')
    end

    it 'rejects searchable on boolean' do
      definition = build(:custom_field_definition, :boolean_field, searchable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable]).to be_present
    end

    it 'allows sortable on short_text and number' do
      expect(build(:custom_field_definition, :short_text_field, sortable: true)).to be_valid
      expect(build(:custom_field_definition, :number_field, sortable: true)).to be_valid
    end

    it 'rejects sortable on long_text' do
      definition = build(:custom_field_definition, :long_text_field, sortable: true)
      expect(definition).not_to be_valid
      expect(definition.errors[:sortable].first).to include('short text', 'number')
      expect(definition.errors[:sortable].first).not_to include('long text')
    end

    it 'rejects changing field_type to a non-searchable class while searchable stays true' do
      definition = create(:custom_field_definition, :short_text_field, searchable: true)
      definition.field_type = 'boolean'
      expect(definition).not_to be_valid
      expect(definition.errors[:searchable]).to be_present
    end

    it 'rejects changing field_type to a non-sortable class while sortable stays true' do
      definition = create(:custom_field_definition, :short_text_field, sortable: true)
      definition.field_type = 'long_text'
      expect(definition).not_to be_valid
      expect(definition.errors[:sortable]).to be_present
    end
  end

  describe '.searchable_field_type_tokens / .sortable_field_type_tokens' do
    it 'derives tokens from custom_field type class capabilities' do
      expect(described_class.searchable_field_type_tokens).to match_array(%w[short_text long_text number])
      expect(described_class.sortable_field_type_tokens).to match_array(%w[short_text number])
    end
  end

  describe '#filter_key' do
    it 'combines the namespace and key' do
      custom_field_definition = build(:custom_field_definition, namespace: 'custom', key: 'material')

      expect(custom_field_definition.filter_key).to eq('cf_custom_material')
    end
  end

  describe 'filter_key uniqueness' do
    # (a_b, c) and (a, b_c) both flatten to `cf_a_b_c`, which would make one
    # definition unreachable via sort/filter params.
    it 'rejects a definition whose filter_key collides across a different namespace split' do
      create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a_b', key: 'c')
      colliding = build(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a', key: 'b_c')

      expect(colliding).not_to be_valid
      expect(colliding.errors[:key]).to be_present
    end

    it 'allows the same namespace/key split on a different resource type' do
      create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a_b', key: 'c')
      other_resource = build(:custom_field_definition, resource_type: 'Spree::Variant', namespace: 'a', key: 'b_c')

      expect(other_resource).to be_valid
    end

    it 'does not flag a persisted definition against itself' do
      custom_field_definition = create(:custom_field_definition, namespace: 'custom', key: 'material')

      custom_field_definition.label = 'Renamed'

      expect(custom_field_definition).to be_valid
    end
  end

  describe 'Ransack allowlist' do
    it 'allows filtering by searchable and sortable' do
      matching = create(:custom_field_definition, :short_text_field, :searchable, :sortable, key: 'ransack_match')
      create(:custom_field_definition, :short_text_field, key: 'ransack_other')

      result = described_class.ransack(searchable_eq: true, sortable_eq: true).result
      expect(result).to include(matching)
      expect(result.map(&:key)).not_to include('ransack_other')
    end
  end

  describe '#csv_header_name' do
    it 'returns the CSV header name with custom_field prefix' do
      custom_field_definition = build(:custom_field_definition, namespace: 'custom', key: 'field1')
      expect(custom_field_definition.csv_header_name).to eq('custom_field.custom.field1')
    end
  end

  describe '#full_key' do
    it 'returns the full key with namespace' do
      custom_field_definition = build(:custom_field_definition, namespace: 'custom', key: 'field1')
      expect(custom_field_definition.full_key).to eq('custom.field1')
    end
  end
end
