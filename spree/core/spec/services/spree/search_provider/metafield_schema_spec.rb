# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SearchProvider::MetafieldSchema do
  subject(:schema) { described_class.new }

  describe 'accessors' do
    it 'exposes definitions by cf_* key' do
      definition = create(:metafield_definition, :number_field, :sortable, :searchable,
                          namespace: 'custom', key: 'weight', name: 'Weight')

      entry = schema.entry_for('cf_custom_weight')

      expect(entry).to eq(definition)
      expect(schema.searchable_attribute_keys).to include('cf_custom_weight')
      expect(schema.sortable_attribute_keys).to include('cf_custom_weight')
    end
  end

  describe '#entries' do
    it 'exposes participating definitions keyed by filter_key' do
      label = create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label')
      priority = create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'priority')

      expect(schema.entries).to include(
        'cf_custom_label' => label,
        'cf_custom_priority' => priority
      )
    end
  end

  describe '#parse_sort' do
    before do
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'name')
    end

    it 'parses ascending and descending cf_* sorts' do
      expect(schema.parse_sort('cf_custom_name')).to eq(attribute: 'cf_custom_name', direction: 'asc')
      expect(schema.parse_sort('-cf_custom_name')).to eq(attribute: 'cf_custom_name', direction: 'desc')
    end

    it 'returns nil for unknown or non-sortable keys' do
      create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'notes')

      expect(schema.parse_sort('cf_custom_unknown')).to be_nil
      expect(schema.parse_sort('name')).to be_nil
      expect(schema.parse_sort('cf_custom_notes')).to be_nil
    end
  end

  describe '#parse_filter' do
    let!(:label) { create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label') }
    let!(:weight) { create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'weight') }

    it 'splits a cf_* predicate key into definition and predicate' do
      expect(schema.parse_filter('cf_custom_label_cont')).to eq(definition: label, predicate: 'cont')
      expect(schema.parse_filter('cf_custom_weight_gteq')).to eq(definition: weight, predicate: 'gteq')
    end

    it 'rejects predicates the field type does not support' do
      expect(schema.parse_filter('cf_custom_weight_cont')).to be_nil
      expect(schema.parse_filter('cf_custom_label_gteq')).to be_nil
    end

    it 'returns nil for unknown, bare, and non-cf keys' do
      expect(schema.parse_filter('cf_custom_unknown_eq')).to be_nil
      expect(schema.parse_filter('cf_custom_label')).to be_nil
      expect(schema.parse_filter('name_cont')).to be_nil
      expect(schema.parse_filter(nil)).to be_nil
    end

    # A key ending in a predicate name (`label_eq`) is ambiguous with
    # `label` + the `eq` predicate. Longest-key-first resolution makes the
    # more specific definition win.
    it 'prefers the longest matching search key when a key ends in a predicate name' do
      label_eq = create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label_eq')

      expect(schema.parse_filter('cf_custom_label_eq_cont')).to eq(definition: label_eq, predicate: 'cont')
      expect(schema.parse_filter('cf_custom_label_eq')).to eq(definition: label, predicate: 'eq')
    end
  end

  describe '#filterable_attribute_keys' do
    it 'returns every participating search key' do
      create(:metafield_definition, :short_text_field, :searchable, namespace: 'custom', key: 'label')
      create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'weight')

      expect(schema.filterable_attribute_keys).to contain_exactly('cf_custom_label', 'cf_custom_weight')
    end
  end

  describe '#sort_ids' do
    before do
      create(:metafield_definition, :short_text_field, :sortable, namespace: 'custom', key: 'color')
      create(:metafield_definition, :number_field, :sortable, namespace: 'custom', key: 'weight')
    end

    it 'returns both ascending and descending variants' do
      expect(schema.sort_ids).to contain_exactly(
        'cf_custom_color', '-cf_custom_color',
        'cf_custom_weight', '-cf_custom_weight'
      )
    end
  end

  describe '#sort_options' do
    it 'returns labeled ascending and descending options for text fields' do
      create(:metafield_definition, :short_text_field, :sortable,
             namespace: 'custom', key: 'label', name: 'Material')

      expect(schema.sort_options).to include(
        { id: 'cf_custom_label', label: "Material (#{Spree.t(:sort_a_to_z)})" },
        { id: '-cf_custom_label', label: "Material (#{Spree.t(:sort_z_to_a)})" }
      )
    end

    it 'returns low-high labels for number fields' do
      create(:metafield_definition, :number_field, :sortable,
             namespace: 'custom', key: 'weight', name: 'Weight')

      expect(schema.sort_options).to include(
        { id: 'cf_custom_weight', label: "Weight (#{Spree.t(:sort_low_to_high)})" },
        { id: '-cf_custom_weight', label: "Weight (#{Spree.t(:sort_high_to_low)})" }
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

      expect(labels['cf_custom_weight'][:label]).to eq('Weight (od najniższej)')
      expect(labels['-cf_custom_weight'][:label]).to eq('Weight (od najwyższej)')
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
