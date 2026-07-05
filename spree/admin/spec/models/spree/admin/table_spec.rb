require 'spec_helper'

RSpec.describe Spree::Admin::Table do
  let(:table) { described_class.new(:products, model_class: Spree::Product) }

  describe '#initialize' do
    it 'sets the context' do
      expect(table.context).to eq(:products)
    end

    it 'sets the model class' do
      expect(table.model_class).to eq(Spree::Product)
    end

    it 'sets default values' do
      expect(table.search_param).to eq(:name_cont)
      expect(table.new_resource).to be true
      expect(table.row_actions).to be false
      expect(table.row_actions_edit).to be true
      expect(table.row_actions_delete).to be false
    end

    it 'allows custom options' do
      custom_table = described_class.new(:orders,
        model_class: Spree::Order,
        search_param: :number_cont,
        row_actions: true,
        new_resource: false,
        date_range_param: :completed_at
      )

      expect(custom_table.search_param).to eq(:number_cont)
      expect(custom_table.row_actions).to be true
      expect(custom_table.new_resource).to be false
      expect(custom_table.date_range_param).to eq(:completed_at)
    end
  end

  describe '#add' do
    it 'adds a column' do
      column = table.add(:name, label: :name, type: :string)

      expect(table.find(:name)).to eq(column)
    end

    it 'converts key to symbol' do
      table.add('name', label: :name)

      expect(table.find(:name)).to be_present
    end

    it 'sorts columns by position' do
      table.add(:status, label: :status, position: 20)
      table.add(:name, label: :name, position: 10)
      table.add(:price, label: :price, position: 30)

      keys = table.available_columns.map(&:key)
      expect(keys).to eq(%w[name status price])
    end

    it 'raises ArgumentError with helpful message when column is invalid' do
      expect {
        table.add(:bad_column)
      }.to raise_error(ArgumentError, "Invalid column 'bad_column' in table 'products': Label can't be blank")
    end

    it 'raises ArgumentError when type is invalid' do
      expect {
        table.add(:bad_column, label: :test, type: :invalid_type)
      }.to raise_error(ArgumentError, /Invalid column 'bad_column' in table 'products':.*Type is not included/)
    end
  end

  describe '#remove' do
    it 'removes a column' do
      table.add(:name, label: :name)
      table.remove(:name)

      expect(table.find(:name)).to be_nil
    end

    it 'returns nil for non-existent column' do
      expect(table.remove(:nonexistent)).to be_nil
    end
  end

  describe '#update' do
    it 'updates an existing column' do
      table.add(:name, label: :name, sortable: false)
      table.update(:name, label: 'Product Name', sortable: true)

      column = table.find(:name)
      expect(column.label).to eq('Product Name')
      expect(column.sortable).to be true
    end

    it 'returns nil for non-existent column' do
      result = table.update(:nonexistent, label: 'Test')

      expect(result).to be_nil
    end
  end

  describe '#find' do
    it 'finds a column by key' do
      column = table.add(:name, label: :name)

      expect(table.find(:name)).to eq(column)
    end

    it 'returns nil for non-existent column' do
      expect(table.find(:nonexistent)).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns true when column exists' do
      table.add(:name, label: :name)

      expect(table.exists?(:name)).to be true
    end

    it 'returns false when column does not exist' do
      expect(table.exists?(:nonexistent)).to be false
    end
  end

  describe '#insert_before' do
    it 'inserts column before target' do
      table.add(:status, label: :status, position: 20)
      table.insert_before(:status, :name, label: :name)

      name = table.find(:name)
      status = table.find(:status)

      expect(name.position).to be < status.position
    end

    it 'returns nil if target does not exist' do
      result = table.insert_before(:nonexistent, :name, label: :name)

      expect(result).to be_nil
    end
  end

  describe '#insert_after' do
    it 'inserts column after target' do
      table.add(:name, label: :name, position: 10)
      table.insert_after(:name, :status, label: :status)

      name = table.find(:name)
      status = table.find(:status)

      expect(status.position).to be > name.position
    end
  end

  describe '#visible_columns' do
    before do
      table.add(:name, label: :name, default: true)
      table.add(:status, label: :status, default: true)
      table.add(:hidden, label: :hidden, default: false)
    end

    it 'returns default columns when no selection' do
      columns = table.visible_columns
      expect(columns.map(&:key)).to contain_exactly('name', 'status')
    end

    it 'returns selected columns when provided' do
      columns = table.visible_columns([:name, :hidden])
      expect(columns.map(&:key)).to contain_exactly('name', 'hidden')
    end

    it 'filters based on visibility condition' do
      table.add(:conditional, label: :conditional, default: true, if: -> { false })

      columns = table.visible_columns(nil, Object.new)
      expect(columns.map(&:key)).to contain_exactly('name', 'status')
    end
  end

  describe '#default_columns' do
    it 'returns only default columns' do
      table.add(:name, label: :name, default: true)
      table.add(:status, label: :status, default: true)
      table.add(:hidden, label: :hidden, default: false)

      columns = table.default_columns
      expect(columns.map(&:key)).to contain_exactly('name', 'status')
    end

    it 'returns columns sorted by position' do
      table.add(:status, label: :status, default: true, position: 20)
      table.add(:name, label: :name, default: true, position: 10)

      columns = table.default_columns
      expect(columns.map(&:key)).to eq(%w[name status])
    end
  end

  describe '#sortable_columns' do
    it 'returns only sortable columns' do
      table.add(:name, label: :name, sortable: true)
      table.add(:description, label: :description, sortable: false)
      table.add(:status, label: :status, sortable: true)

      columns = table.sortable_columns
      expect(columns.map(&:key)).to contain_exactly('name', 'status')
    end
  end

  describe '#filterable_columns' do
    it 'returns only filterable columns' do
      table.add(:name, label: :name, filterable: true)
      table.add(:image, label: :image, filterable: false)
      table.add(:status, label: :status, filterable: true)

      columns = table.filterable_columns
      expect(columns.map(&:key)).to contain_exactly('name', 'status')
    end
  end

  describe '#add_bulk_action' do
    it 'adds a bulk action' do
      action = table.add_bulk_action(:delete, label: 'Delete', icon: 'trash')

      expect(table.find_bulk_action(:delete)).to eq(action)
    end

    it 'sorts bulk actions by position' do
      table.add_bulk_action(:export, position: 20)
      table.add_bulk_action(:delete, position: 10)

      actions = table.visible_bulk_actions
      expect(actions.map(&:key)).to eq([:delete, :export])
    end

    it 'raises ArgumentError when method is invalid' do
      expect {
        table.add_bulk_action(:bad_action, method: :invalid)
      }.to raise_error(ArgumentError, /Invalid bulk action 'bad_action' in table 'products':.*Method is not included/)
    end
  end

  describe '#remove_bulk_action' do
    it 'removes a bulk action' do
      table.add_bulk_action(:delete)
      table.remove_bulk_action(:delete)

      expect(table.find_bulk_action(:delete)).to be_nil
    end
  end

  describe '#bulk_operations_enabled?' do
    it 'returns false when no bulk actions' do
      expect(table.bulk_operations_enabled?).to be false
    end

    it 'returns true when bulk actions exist' do
      table.add_bulk_action(:delete)
      expect(table.bulk_operations_enabled?).to be true
    end
  end

  describe '#date_range?' do
    it 'returns false when date_range_param is not set' do
      expect(table.date_range?).to be false
    end

    it 'returns true when date_range_param is set' do
      table.date_range_param = :created_at
      expect(table.date_range?).to be true
    end
  end

  describe '#deep_clone' do
    it 'creates a deep copy of the table' do
      table.add(:name, label: :name, default: true)
      table.add_bulk_action(:delete, label: 'Delete', position: 10)

      cloned = table.deep_clone

      expect(cloned.context).to eq(table.context)
      expect(cloned.find(:name).label).to eq(:name)
      expect(cloned.find_bulk_action(:delete).label).to eq('Delete')

      # Verify it's a deep copy
      cloned.update(:name, label: 'Changed')
      expect(table.find(:name).label).to eq(:name)
    end
  end

  describe '#clear' do
    it 'removes all columns' do
      table.add(:name, label: :name)
      table.add(:status, label: :status)
      table.clear

      expect(table.available_columns).to be_empty
    end
  end

  describe '#clear_bulk_actions' do
    it 'removes all bulk actions' do
      table.add_bulk_action(:delete)
      table.add_bulk_action(:export)
      table.clear_bulk_actions

      expect(table.visible_bulk_actions).to be_empty
    end
  end

  describe 'custom sort' do
    it 'finds column with custom sort scope' do
      table.add(:price, label: :price, sortable: true, ransack_attribute: 'price', sort_scope_asc: :ascend_by_price)

      column = table.find_custom_sort_column('price asc')
      expect(column).to be_present
      expect(column.key).to eq('price')
    end

    it 'returns nil for standard sort' do
      table.add(:name, label: :name, sortable: true)

      column = table.find_custom_sort_column('name asc')
      expect(column).to be_nil
    end
  end
end
