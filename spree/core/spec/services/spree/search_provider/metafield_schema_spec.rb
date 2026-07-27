# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SearchProvider::MetafieldSchema do
  subject(:schema) { described_class.new }

  describe 'accessors' do
    it 'exposes definitions by mf_* key' do
      definition = create(:metafield_definition, :number_field, :sortable, :searchable,
                          namespace: 'custom', key: 'weight', name: 'Weight')

      entry = schema.entry_for('mf_6_custom_weight')

      expect(entry).to eq(definition)
      expect(schema.searchable_attribute_keys).to include('mf_6_custom_weight')
      expect(schema.sortable_attribute_keys).to include('mf_6_custom_weight')
    end
  end

  describe '#entries' do
    it 'exposes participating definitions keyed by search_key' do
      label = create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label')
      priority = create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'priority')

      expect(schema.entries).to include(
        'mf_6_custom_label' => label,
        'mf_6_custom_priority' => priority
      )
    end
  end

  describe '#parse_sort' do
    before do
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'name')
    end

    it 'parses ascending and descending mf_* sorts' do
      expect(schema.parse_sort('mf_6_custom_name')).to eq(attribute: 'mf_6_custom_name', direction: 'asc')
      expect(schema.parse_sort('-mf_6_custom_name')).to eq(attribute: 'mf_6_custom_name', direction: 'desc')
    end

    it 'returns nil for unknown or non-sortable keys' do
      create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'notes')

      expect(schema.parse_sort('mf_6_custom_unknown')).to be_nil
      expect(schema.parse_sort('name')).to be_nil
      expect(schema.parse_sort('mf_6_custom_notes')).to be_nil
    end
  end

  describe '#sort_ids' do
    before do
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'color')
      create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'weight')
    end

    it 'returns both ascending and descending variants' do
      expect(schema.sort_ids).to contain_exactly(
        'mf_6_custom_color', '-mf_6_custom_color',
        'mf_6_custom_weight', '-mf_6_custom_weight'
      )
    end
  end

  describe '#sort_options' do
    it 'returns labeled ascending and descending options for text fields' do
      create(:metafield_definition, :short_text_field, :sortable,
             namespace: 'custom', key: 'label', name: 'Material')

      expect(schema.sort_options).to include(
        { id: 'mf_6_custom_label', label: "Material (#{Spree.t(:sort_a_to_z)})" },
        { id: '-mf_6_custom_label', label: "Material (#{Spree.t(:sort_z_to_a)})" }
      )
    end

    it 'returns low-high labels for number fields' do
      create(:metafield_definition, :number_field, :sortable,
             namespace: 'custom', key: 'weight', name: 'Weight')

      expect(schema.sort_options).to include(
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
      labels = schema.sort_options.index_by { |o| o[:id] }

      expect(labels['mf_6_custom_weight'][:label]).to eq('Weight (od najniższej)')
      expect(labels['-mf_6_custom_weight'][:label]).to eq('Weight (od najwyższej)')
    ensure
      I18n.locale = I18n.default_locale
      Spree::Current.locale = nil
    end
  end

  describe '#schema_version' do
    it 'returns a stamp derived from participating entries' do
      definition = create(:metafield_definition, :short_text_field, :sortable,
                          namespace: 'custom', key: 'weight')

      version = schema.schema_version

      expect(version).to start_with('1-')
      expect(version).to include(definition.updated_at.utc.iso8601(6))
    end
  end
end
