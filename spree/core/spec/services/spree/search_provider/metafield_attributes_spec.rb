# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SearchProvider::MetafieldAttributes do
  describe '.registry' do
    before { described_class.clear_cache! }

    it 'caches definition ids and flags by mf_* key' do
      definition = create(:metafield_definition, :number_field, :sortable, :searchable,
                          namespace: 'custom', key: 'weight', name: 'Weight')

      registry = described_class.registry
      entry = registry[:by_key]['mf_6_custom_weight']

      expect(entry[:id]).to eq(definition.id)
      expect(entry[:name]).to eq('Weight')
      expect(entry[:field_type]).to eq('number')
      expect(entry[:searchable]).to eq(true)
      expect(entry[:sortable]).to eq(true)
      expect(registry[:searchable_keys]).to include('mf_6_custom_weight')
      expect(registry[:sortable_keys]).to include('mf_6_custom_weight')
    end

    it 'rebuilds after clear_cache!' do
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'a')
      expect(described_class.sortable_attribute_keys).to include('mf_6_custom_a')

      described_class.clear_cache!
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'b')
      expect(described_class.sortable_attribute_keys).to include('mf_6_custom_a', 'mf_6_custom_b')
    end
  end

  describe '.parse_sort' do
    before do
      described_class.clear_cache!
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'name')
    end

    it 'parses ascending and descending mf_* sorts' do
      expect(described_class.parse_sort('mf_6_custom_name')).to eq(attribute: 'mf_6_custom_name', direction: 'asc')
      expect(described_class.parse_sort('-mf_6_custom_name')).to eq(attribute: 'mf_6_custom_name', direction: 'desc')
    end

    it 'returns nil for unknown or non-sortable keys' do
      create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'notes')

      expect(described_class.parse_sort('mf_6_custom_unknown')).to be_nil
      expect(described_class.parse_sort('name')).to be_nil
      expect(described_class.parse_sort('mf_6_custom_notes')).to be_nil
    end
  end

  describe '.sort_options' do
    before { described_class.clear_cache! }

    it 'returns labeled ascending and descending options for text fields' do
      create(:metafield_definition, :short_text_field, :sortable,
             namespace: 'custom', key: 'label', name: 'Material')

      expect(described_class.sort_options).to include(
        { id: 'mf_6_custom_label', label: "Material (#{Spree.t(:sort_a_to_z)})" },
        { id: '-mf_6_custom_label', label: "Material (#{Spree.t(:sort_z_to_a)})" }
      )
    end

    it 'returns low-high labels for number fields' do
      create(:metafield_definition, :number_field, :sortable,
             namespace: 'custom', key: 'weight', name: 'Weight')

      expect(described_class.sort_options).to include(
        { id: 'mf_6_custom_weight', label: "Weight (#{Spree.t(:sort_low_to_high)})" },
        { id: '-mf_6_custom_weight', label: "Weight (#{Spree.t(:sort_high_to_low)})" }
      )
    end

    it 'translates direction suffixes for the current locale' do
      create(:metafield_definition, :number_field, :sortable,
             namespace: 'custom', key: 'weight', name: 'Weight')

      I18n.backend.store_translations(:pl, spree: {
                                        sort_low_to_high: 'od najniższej',
                                        sort_high_to_low: 'od najwyższej'
                                      })

      I18n.locale = :pl
      Spree::Current.locale = 'pl'
      labels = described_class.sort_options.index_by { |o| o[:id] }

      expect(labels['mf_6_custom_weight'][:label]).to eq('Weight (od najniższej)')
      expect(labels['-mf_6_custom_weight'][:label]).to eq('Weight (od najwyższej)')
    ensure
      I18n.locale = I18n.default_locale
      Spree::Current.locale = nil
    end
  end

  describe '.document_attributes' do
    let(:product) { create(:product) }
    let!(:searchable_def) do
      create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label')
    end
    let!(:sortable_def) do
      create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'priority')
    end

    before do
      described_class.clear_cache!
      product.set_metafield(searchable_def, 'wool-blend')
      product.set_metafield(sortable_def, '10')
    end

    it 'indexes searchable and sortable values with native types' do
      attrs = described_class.document_attributes(product.reload)
      expect(attrs['mf_6_custom_label']).to eq('wool-blend')
      expect(attrs['mf_6_custom_priority']).to eq(10.0)
    end
  end

  describe '.sort_expression_sql and .sort_null_rank_sql' do
    it 'casts numeric metafields for PostgreSQL' do
      expr = described_class.sort_expression_sql(field_type: 'number', adapter_name: 'PostgreSQL')
      expect(expr).to eq('sort_mf.value::numeric')

      rank = described_class.sort_null_rank_sql(field_type: 'number', adapter_name: 'PostgreSQL')
      expect(rank).to eq('(sort_mf.value::numeric IS NULL)')
    end

    it 'casts numeric metafields for MySQL' do
      expr = described_class.sort_expression_sql(field_type: 'number', adapter_name: 'Mysql2')
      expect(expr).to eq('CAST(sort_mf.value AS DECIMAL(30, 10))')

      rank = described_class.sort_null_rank_sql(field_type: 'number', adapter_name: 'Mysql2')
      expect(rank).to eq('(CAST(sort_mf.value AS DECIMAL(30, 10)) IS NULL)')
    end

    it 'casts numeric metafields for SQLite and other adapters' do
      expr = described_class.sort_expression_sql(field_type: 'number', adapter_name: 'SQLite')
      expect(expr).to eq('CAST(sort_mf.value AS REAL)')

      rank = described_class.sort_null_rank_sql(field_type: 'number', adapter_name: 'SQLite')
      expect(rank).to eq('(CAST(sort_mf.value AS REAL) IS NULL)')
    end

    it 'handles text fields without casting' do
      expr = described_class.sort_expression_sql(field_type: 'short_text', adapter_name: 'PostgreSQL')
      expect(expr).to eq('sort_mf.value')

      rank = described_class.sort_null_rank_sql(field_type: 'short_text', adapter_name: 'PostgreSQL')
      expect(rank).to eq('(sort_mf.value IS NULL)')
    end
  end
end
