require 'spec_helper'

RSpec.describe Spree::Admin::Table::QueryBuilder do
  let(:table) { Spree::Admin::Table.new(:products, model_class: Spree::Product) }
  let(:query_builder) { described_class.new(table) }

  before do
    table.add(:name, label: 'Name', type: :string, filterable: true)
    table.add(:status, label: 'Status', type: :status, filterable: true, value_options: %w[active draft archived])
    table.add(:price, label: 'Price', type: :money, filterable: true)
    table.add(:created_at, label: 'Created', type: :datetime, filterable: true)
  end

  describe '#initialize' do
    it 'sets the table' do
      expect(query_builder.table).to eq(table)
    end

    it 'creates an empty root group' do
      expect(query_builder.root_group).to be_a(Spree::Admin::Table::FilterGroup)
      expect(query_builder.root_group.empty?).to be true
    end
  end

  describe '#add_filter' do
    it 'adds a filter to the root group' do
      filter = query_builder.add_filter(field: 'name', operator: :cont, value: 'test')

      expect(filter).to be_a(Spree::Admin::Table::Filter)
      expect(query_builder.root_group.filters).to include(filter)
    end
  end

  describe '#add_group' do
    it 'adds a nested group' do
      group = query_builder.add_group(combinator: :or)

      expect(group).to be_a(Spree::Admin::Table::FilterGroup)
      expect(query_builder.root_group.groups).to include(group)
    end
  end

  describe '#clear' do
    it 'resets the root group' do
      query_builder.add_filter(field: 'name', operator: :cont, value: 'test')
      query_builder.clear

      expect(query_builder.empty?).to be true
    end
  end

  describe '#empty?' do
    it 'returns true when no filters' do
      expect(query_builder.empty?).to be true
    end

    it 'returns false when has filters' do
      query_builder.add_filter(field: 'name', operator: :cont, value: 'test')
      expect(query_builder.empty?).to be false
    end
  end

  describe '#to_ransack_params' do
    it 'returns ransack params from filters' do
      query_builder.add_filter(field: 'name', operator: :cont, value: 'test')
      query_builder.add_filter(field: 'status', operator: :eq, value: 'active')

      params = query_builder.to_ransack_params

      expect(params['name_cont']).to eq('test')
      expect(params['status_eq']).to eq('active')
    end
  end

  describe '#to_json_state' do
    it 'returns JSON string representation' do
      query_builder.add_filter(field: 'name', operator: :cont, value: 'test')

      json = query_builder.to_json_state
      parsed = JSON.parse(json)

      expect(parsed['combinator']).to eq('and')
      expect(parsed['filters'].first['field']).to eq('name')
    end
  end

  describe '#load_from_params' do
    it 'loads state from params hash' do
      params = {
        combinator: 'and',
        filters: [
          { field: 'name', operator: 'cont', value: 'test' }
        ],
        groups: []
      }

      query_builder.load_from_params(params)

      expect(query_builder.root_group.filters.size).to eq(1)
      expect(query_builder.root_group.filters.first.field).to eq('name')
    end
  end

  describe '#load_from_json' do
    it 'loads state from JSON string' do
      json = {
        combinator: 'and',
        filters: [
          { field: 'name', operator: 'cont', value: 'test' }
        ],
        groups: []
      }.to_json

      query_builder.load_from_json(json)

      expect(query_builder.root_group.filters.size).to eq(1)
    end

    it 'handles invalid JSON gracefully' do
      query_builder.load_from_json('invalid json')
      expect(query_builder.empty?).to be true
    end

    it 'handles blank string' do
      query_builder.load_from_json('')
      expect(query_builder.empty?).to be true
    end
  end

  describe '#available_fields' do
    it 'returns array of field configurations' do
      fields = query_builder.available_fields

      expect(fields).to be_an(Array)
      expect(fields.size).to eq(4)
    end

    it 'includes field key' do
      fields = query_builder.available_fields
      name_field = fields.find { |f| f[:key] == 'name' }

      expect(name_field[:key]).to eq('name')
    end

    it 'includes label' do
      fields = query_builder.available_fields
      name_field = fields.find { |f| f[:key] == 'name' }

      expect(name_field[:label]).to eq('Name')
    end

    it 'includes filter type' do
      fields = query_builder.available_fields
      status_field = fields.find { |f| f[:key] == 'status' }

      expect(status_field[:type]).to eq('status')
    end

    it 'includes operators' do
      fields = query_builder.available_fields
      name_field = fields.find { |f| f[:key] == 'name' }

      expect(name_field[:operators]).to include('eq', 'cont')
    end

    it 'includes value_options for select fields' do
      fields = query_builder.available_fields
      status_field = fields.find { |f| f[:key] == 'status' }

      expect(status_field[:value_options]).to be_present
      expect(status_field[:value_options].map { |o| o[:value] }).to include('active', 'draft', 'archived')
    end

    it 'resolves lambda value_options' do
      table.update(:status, value_options: -> { %w[one two three] })

      fields = query_builder.available_fields
      status_field = fields.find { |f| f[:key] == 'status' }

      expect(status_field[:value_options].map { |o| o[:value] }).to include('one', 'two', 'three')
    end
  end

  describe '#available_operators' do
    it 'returns array of operator options' do
      operators = query_builder.available_operators

      expect(operators).to be_an(Array)
      expect(operators.first).to include(:value, :label)
    end
  end
end
