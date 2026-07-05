require 'spec_helper'

RSpec.describe Spree::Admin::Table::FilterGroup do
  describe '#initialize' do
    it 'sets default values' do
      group = described_class.new

      expect(group.combinator).to eq(:and)
      expect(group.filters).to eq([])
      expect(group.groups).to eq([])
      expect(group.id).to be_present
    end

    it 'accepts custom options' do
      group = described_class.new(combinator: :or, id: 'custom-id')

      expect(group.combinator).to eq(:or)
      expect(group.id).to eq('custom-id')
    end

    it 'converts combinator to symbol' do
      group = described_class.new(combinator: 'or')
      expect(group.combinator).to eq(:or)
    end
  end

  describe '#add_filter' do
    it 'adds a filter to the group' do
      group = described_class.new
      filter = Spree::Admin::Table::Filter.new(field: 'name')

      group.add_filter(filter)

      expect(group.filters).to include(filter)
    end
  end

  describe '#add_group' do
    it 'adds a nested group' do
      parent = described_class.new
      child = described_class.new(combinator: :or)

      parent.add_group(child)

      expect(parent.groups).to include(child)
    end
  end

  describe '#remove_filter' do
    it 'removes filter by id' do
      group = described_class.new
      filter1 = Spree::Admin::Table::Filter.new(field: 'name', id: 'f1')
      filter2 = Spree::Admin::Table::Filter.new(field: 'status', id: 'f2')

      group.add_filter(filter1)
      group.add_filter(filter2)
      group.remove_filter('f1')

      expect(group.filters.map(&:id)).to eq(['f2'])
    end
  end

  describe '#remove_group' do
    it 'removes group by id' do
      parent = described_class.new
      child1 = described_class.new(id: 'g1')
      child2 = described_class.new(id: 'g2')

      parent.add_group(child1)
      parent.add_group(child2)
      parent.remove_group('g1')

      expect(parent.groups.map(&:id)).to eq(['g2'])
    end
  end

  describe '#empty?' do
    it 'returns true when no filters or groups' do
      group = described_class.new
      expect(group.empty?).to be true
    end

    it 'returns false when has filters' do
      group = described_class.new
      group.add_filter(Spree::Admin::Table::Filter.new(field: 'name'))
      expect(group.empty?).to be false
    end

    it 'returns false when has nested groups' do
      group = described_class.new
      group.add_group(described_class.new)
      expect(group.empty?).to be false
    end
  end

  describe '#to_ransack_params' do
    context 'with AND combinator' do
      it 'returns merged filter params' do
        group = described_class.new(combinator: :and)
        group.add_filter(Spree::Admin::Table::Filter.new(field: 'name', operator: :cont, value: 'test'))
        group.add_filter(Spree::Admin::Table::Filter.new(field: 'status', operator: :eq, value: 'active'))

        params = group.to_ransack_params

        expect(params).to eq({
          'name_cont' => 'test',
          'status_eq' => 'active'
        })
      end

      it 'handles nested OR groups' do
        group = described_class.new(combinator: :and)
        group.add_filter(Spree::Admin::Table::Filter.new(field: 'name', operator: :cont, value: 'test'))

        or_group = described_class.new(combinator: :or)
        or_group.add_filter(Spree::Admin::Table::Filter.new(field: 'status', operator: :eq, value: 'active'))
        or_group.add_filter(Spree::Admin::Table::Filter.new(field: 'status', operator: :eq, value: 'draft'))
        group.add_group(or_group)

        params = group.to_ransack_params

        expect(params['name_cont']).to eq('test')
        expect(params[:g]).to be_present
      end
    end

    context 'with OR combinator' do
      it 'returns ransack grouping format' do
        group = described_class.new(combinator: :or)
        group.add_filter(Spree::Admin::Table::Filter.new(field: 'name', operator: :cont, value: 'test'))
        group.add_filter(Spree::Admin::Table::Filter.new(field: 'description', operator: :cont, value: 'test'))

        params = group.to_ransack_params

        expect(params[:g]).to be_present
        expect(params[:g]['0'][:m]).to eq('or')
      end
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      group = described_class.new(combinator: :and, id: 'root')
      filter = Spree::Admin::Table::Filter.new(field: 'name', id: 'f1')
      group.add_filter(filter)

      hash = group.to_h

      expect(hash[:combinator]).to eq(:and)
      expect(hash[:id]).to eq('root')
      expect(hash[:filters].first[:field]).to eq('name')
      expect(hash[:groups]).to eq([])
    end
  end

  describe '.from_params' do
    it 'creates group from params hash' do
      params = {
        combinator: 'and',
        id: 'root',
        filters: [
          { field: 'name', operator: 'cont', value: 'test', id: 'f1' }
        ],
        groups: []
      }

      group = described_class.from_params(params)

      expect(group.combinator).to eq(:and)
      expect(group.id).to eq('root')
      expect(group.filters.size).to eq(1)
      expect(group.filters.first.field).to eq('name')
    end

    it 'handles nested groups' do
      params = {
        combinator: 'and',
        filters: [],
        groups: [
          {
            combinator: 'or',
            filters: [
              { field: 'status', operator: 'eq', value: 'active' }
            ],
            groups: []
          }
        ]
      }

      group = described_class.from_params(params)

      expect(group.groups.size).to eq(1)
      expect(group.groups.first.combinator).to eq(:or)
      expect(group.groups.first.filters.size).to eq(1)
    end

    it 'returns empty group for blank params' do
      group = described_class.from_params(nil)
      expect(group.empty?).to be true
    end
  end
end
