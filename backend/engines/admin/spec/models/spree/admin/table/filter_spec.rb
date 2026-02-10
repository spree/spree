require 'spec_helper'

RSpec.describe Spree::Admin::Table::Filter do
  describe '#initialize' do
    it 'sets default values' do
      filter = described_class.new

      expect(filter.field).to be_nil
      expect(filter.operator).to eq(:eq)
      expect(filter.value).to be_nil
      expect(filter.id).to be_present
    end

    it 'accepts custom options' do
      filter = described_class.new(
        field: 'name',
        operator: :cont,
        value: 'test',
        id: 'custom-id'
      )

      expect(filter.field).to eq('name')
      expect(filter.operator).to eq(:cont)
      expect(filter.value).to eq('test')
      expect(filter.id).to eq('custom-id')
    end

    it 'converts operator to symbol' do
      filter = described_class.new(operator: 'cont')
      expect(filter.operator).to eq(:cont)
    end
  end

  describe '#to_ransack_param' do
    it 'returns empty hash when field is blank' do
      filter = described_class.new(field: nil, value: 'test')
      expect(filter.to_ransack_param).to eq({})
    end

    it 'generates correct param for eq operator' do
      filter = described_class.new(field: 'name', operator: :eq, value: 'Test')
      expect(filter.to_ransack_param).to eq({ 'name_eq' => 'Test' })
    end

    it 'generates correct param for cont operator' do
      filter = described_class.new(field: 'name', operator: :cont, value: 'Test')
      expect(filter.to_ransack_param).to eq({ 'name_cont' => 'Test' })
    end

    it 'generates correct param for in operator' do
      filter = described_class.new(field: 'status', operator: :in, value: %w[active draft])
      expect(filter.to_ransack_param).to eq({ 'status_in' => %w[active draft] })
    end

    it 'generates correct param for not_in operator' do
      filter = described_class.new(field: 'status', operator: :not_in, value: %w[archived])
      expect(filter.to_ransack_param).to eq({ 'status_not_in' => ['archived'] })
    end

    it 'generates correct param for null operator' do
      filter = described_class.new(field: 'deleted_at', operator: :null)
      expect(filter.to_ransack_param).to eq({ 'deleted_at_null' => true })
    end

    it 'generates correct param for not_null operator' do
      filter = described_class.new(field: 'completed_at', operator: :not_null)
      expect(filter.to_ransack_param).to eq({ 'completed_at_not_null' => true })
    end

    it 'generates correct param for comparison operators' do
      filter = described_class.new(field: 'price', operator: :gt, value: 100)
      expect(filter.to_ransack_param).to eq({ 'price_gt' => 100 })
    end

    it 'extracts ids from autocomplete array values' do
      filter = described_class.new(
        field: 'taxon_id',
        operator: :in,
        value: [{ 'id' => 1, 'name' => 'Category' }, { 'id' => 2, 'name' => 'Brand' }]
      )
      expect(filter.to_ransack_param).to eq({ 'taxon_id_in' => [1, 2] })
    end

    it 'handles single value arrays for eq operator' do
      filter = described_class.new(
        field: 'taxon_id',
        operator: :eq,
        value: [{ 'id' => 1, 'name' => 'Category' }]
      )
      expect(filter.to_ransack_param).to eq({ 'taxon_id_eq' => 1 })
    end
  end

  describe '#operator_label' do
    it 'returns human readable label for operator' do
      filter = described_class.new(operator: :cont)
      expect(filter.operator_label).to eq('contains')
    end

    it 'returns humanized operator for unknown operator' do
      filter = described_class.new(operator: :unknown)
      expect(filter.operator_label).to eq('Unknown')
    end
  end

  describe '#requires_value?' do
    it 'returns true for eq operator' do
      filter = described_class.new(operator: :eq)
      expect(filter.requires_value?).to be true
    end

    it 'returns true for cont operator' do
      filter = described_class.new(operator: :cont)
      expect(filter.requires_value?).to be true
    end

    it 'returns false for null operator' do
      filter = described_class.new(operator: :null)
      expect(filter.requires_value?).to be false
    end

    it 'returns false for not_null operator' do
      filter = described_class.new(operator: :not_null)
      expect(filter.requires_value?).to be false
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      filter = described_class.new(
        field: 'name',
        operator: :cont,
        value: 'test',
        id: 'filter-1'
      )

      hash = filter.to_h
      expect(hash[:field]).to eq('name')
      expect(hash[:operator]).to eq(:cont)
      expect(hash[:value]).to eq('test')
      expect(hash[:id]).to eq('filter-1')
    end
  end

  describe '.from_params' do
    it 'creates filter from params hash' do
      params = { field: 'name', operator: 'cont', value: 'test', id: 'f1' }
      filter = described_class.from_params(params)

      expect(filter.field).to eq('name')
      expect(filter.operator).to eq(:cont)
      expect(filter.value).to eq('test')
      expect(filter.id).to eq('f1')
    end

    it 'uses default operator when not provided' do
      params = { field: 'name', value: 'test' }
      filter = described_class.from_params(params)

      expect(filter.operator).to eq(:eq)
    end

    it 'returns nil for non-hash params' do
      expect(described_class.from_params(nil)).to be_nil
      expect(described_class.from_params('invalid')).to be_nil
    end
  end

  describe '.operators_for_select' do
    it 'returns array of operator options' do
      options = described_class.operators_for_select

      expect(options).to be_an(Array)
      expect(options.first).to include(:value, :label, :no_value)
    end

    it 'includes all defined operators' do
      options = described_class.operators_for_select
      values = options.map { |o| o[:value] }

      expect(values).to include('eq', 'not_eq', 'cont', 'in', 'not_in', 'null', 'not_null')
    end
  end
end
