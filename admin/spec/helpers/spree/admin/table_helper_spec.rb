require 'spec_helper'

RSpec.describe Spree::Admin::TableHelper, type: :helper do
  let(:table) { Spree::Admin::Table.new(:products, model_class: Spree::Product) }
  let(:product) { create(:product, name: 'Test Product', price: 19.99) }

  before do
    table.add(:name, label: :name, type: 'string', default: true, position: 10)
    table.add(:price, label: :price, type: 'money', default: true, position: 20)
    table.add(:status, label: :status, type: 'status', default: true, position: 30)
    table.add(:created_at, label: :created_at, type: 'datetime', default: true, position: 40)
  end

  describe '#session_selected_columns' do
    it 'returns nil when no columns in session' do
      expect(helper.session_selected_columns(:products)).to be_nil
    end

    it 'returns array of strings when columns are in session' do
      session['table_columns_products'] = 'name,price,status'

      result = helper.session_selected_columns(:products)

      expect(result).to eq(%w[name price status])
    end

    it 'returns nil for empty string' do
      session['table_columns_products'] = ''

      expect(helper.session_selected_columns(:products)).to be_nil
    end
  end

  describe '#render_column_value' do
    describe 'with string type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'name', label: :name, type: 'string') }

      it 'renders string value' do
        result = helper.render_column_value(product, column, table)

        expect(result).to include('Test Product')
      end

      it 'renders dash for blank value' do
        product.name = nil
        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
        expect(result).to include('text-gray-400')
      end

      it 'truncates long strings' do
        product.name = 'A' * 150
        result = helper.render_column_value(product, column, table)

        expect(result.length).to be < 150
        expect(result).to include('...')
      end
    end

    describe 'with money type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'price', label: :price, type: 'money') }

      before do
        allow(helper).to receive(:current_currency).and_return('USD')
      end

      it 'renders money value with symbol' do
        result = helper.render_column_value(product, column, table)

        expect(result).to include('$')
        expect(result).to include('19.99')
      end

      it 'renders dash for blank value' do
        column = Spree::Admin::Table::Column.new(key: 'cost_price', label: :cost_price, type: 'money', method: :cost_price)
        allow(product).to receive(:cost_price).and_return(nil)

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end

      it 'uses display_amount if available' do
        money_object = double('Money', display_amount: '$25.00')
        column = Spree::Admin::Table::Column.new(key: 'total', label: :total, type: 'money', method: ->(r) { money_object })

        result = helper.render_column_value(product, column, table)

        expect(result).to eq('$25.00')
      end
    end

    describe 'with date type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'available_on', label: :available_on, type: 'date', method: :available_on) }

      it 'renders formatted date using spree_date' do
        product.available_on = Date.new(2025, 6, 15)
        allow(helper).to receive(:spree_date).and_return('Jun 15, 2025')

        result = helper.render_column_value(product, column, table)

        expect(helper).to have_received(:spree_date)
        expect(result).to eq('Jun 15, 2025')
      end

      it 'renders dash for blank value' do
        product.available_on = nil

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end

    describe 'with datetime type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'created_at', label: :created_at, type: 'datetime') }

      before do
        allow(helper).to receive(:spree_time_ago).and_return('2 hours ago')
      end

      it 'renders datetime using spree_time_ago' do
        result = helper.render_column_value(product, column, table)

        expect(helper).to have_received(:spree_time_ago)
        expect(result).to eq('2 hours ago')
      end

      it 'renders dash for blank value' do
        column = Spree::Admin::Table::Column.new(key: 'deleted_at', label: :deleted_at, type: 'datetime', method: :deleted_at)
        allow(product).to receive(:deleted_at).and_return(nil)

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end

    describe 'with status type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'status', label: :status, type: 'status') }

      it 'renders active status with badge-active class' do
        allow(product).to receive(:status).and_return('active')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('badge')
        expect(result).to include('badge-active')
      end

      it 'renders draft status with badge-warning class' do
        allow(product).to receive(:status).and_return('draft')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('badge-warning')
      end

      it 'renders archived status with badge-inactive class' do
        allow(product).to receive(:status).and_return('archived')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('badge-inactive')
      end

      it 'renders unknown status with badge-secondary class' do
        allow(product).to receive(:status).and_return('custom_status')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('badge-secondary')
      end

      it 'renders dash for blank value' do
        allow(product).to receive(:status).and_return(nil)

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end

    describe 'with boolean type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'available', label: :available, type: 'boolean', method: :available?) }

      before do
        allow(helper).to receive(:active_badge).and_call_original
      end

      it 'renders boolean value using active_badge' do
        allow(product).to receive(:available?).and_return(true)
        allow(helper).to receive(:active_badge).with(true).and_return('<span>Yes</span>'.html_safe)

        result = helper.render_column_value(product, column, table)

        expect(helper).to have_received(:active_badge).with(true)
      end
    end

    describe 'with link type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'name', label: :name, type: 'link') }

      it 'renders link with value' do
        allow(helper).to receive(:edit_object_url).with(product).and_return('/admin/products/1/edit')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('Test Product')
        expect(result).to include('href="/admin/products/1/edit"')
      end

      it 'renders plain text when no URL available' do
        allow(helper).to receive(:respond_to?).with(:object_url).and_return(false)
        allow(helper).to receive(:respond_to?).with(:edit_object_url).and_return(false)
        allow(helper).to receive(:respond_to?).with(anything).and_call_original

        result = helper.render_column_value(product, column, table)

        expect(result).to include('Test Product')
        expect(result).not_to include('href')
      end

      it 'renders dash for blank value' do
        product.name = nil

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end

    describe 'with image type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'image', label: :image, type: 'image', method: :gallery_image_url) }

      it 'renders image tag for string URL' do
        allow(product).to receive(:gallery_image_url).and_return('https://example.com/image.jpg')

        result = helper.render_column_value(product, column, table)

        expect(result).to include('<img')
        expect(result).to include('https://example.com/image.jpg')
        expect(result).to include('loading="lazy"')
      end

      it 'renders dash for blank value' do
        allow(product).to receive(:gallery_image_url).and_return(nil)

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end

    describe 'with custom type' do
      let(:column) do
        Spree::Admin::Table::Column.new(
          key: 'custom_field',
          label: :custom,
          type: 'custom',
          partial: 'spree/admin/tables/columns/custom_test'
        )
      end

      it 'renders custom partial with locals' do
        allow(helper).to receive(:render).with(
          partial: 'spree/admin/tables/columns/custom_test',
          locals: hash_including(record: product, column: column)
        ).and_return('custom content')

        result = helper.render_column_value(product, column, table)

        expect(result).to eq('custom content')
      end

      it 'supports partial_locals as hash' do
        column = Spree::Admin::Table::Column.new(
          key: 'custom_field',
          label: :custom,
          type: 'custom',
          partial: 'spree/admin/tables/columns/custom_test',
          partial_locals: { extra: 'data' }
        )

        allow(helper).to receive(:render).with(
          partial: 'spree/admin/tables/columns/custom_test',
          locals: hash_including(extra: 'data')
        ).and_return('custom content')

        result = helper.render_column_value(product, column, table)

        expect(result).to eq('custom content')
      end

      it 'supports partial_locals as proc' do
        column = Spree::Admin::Table::Column.new(
          key: 'custom_field',
          label: :custom,
          type: 'custom',
          partial: 'spree/admin/tables/columns/custom_test',
          partial_locals: ->(record) { { product_name: record.name } }
        )

        allow(helper).to receive(:render).with(
          partial: 'spree/admin/tables/columns/custom_test',
          locals: hash_including(product_name: 'Test Product')
        ).and_return('custom content')

        result = helper.render_column_value(product, column, table)

        expect(result).to eq('custom content')
      end
    end

    describe 'with association type' do
      let(:column) { Spree::Admin::Table::Column.new(key: 'taxons', label: :taxons, type: 'association', method: ->(p) { 'Category 1, Category 2' }) }

      it 'renders association value' do
        result = helper.render_column_value(product, column, table)

        expect(result).to include('Category 1, Category 2')
      end

      it 'renders dash for blank value' do
        column = Spree::Admin::Table::Column.new(key: 'taxons', label: :taxons, type: 'association', method: ->(p) { nil })

        result = helper.render_column_value(product, column, table)

        expect(result).to include('-')
      end
    end
  end

  describe '#render_money_column' do
    let(:column) { Spree::Admin::Table::Column.new(key: 'price', label: :price, type: 'money') }

    before do
      allow(helper).to receive(:current_currency).and_return('USD')
    end

    it 'renders Spree::Money for numeric value' do
      result = helper.render_money_column(19.99, column)

      expect(result).to include('$')
      expect(result).to include('19.99')
    end

    it 'calls display_amount on objects that respond to it' do
      money = double('Money', display_amount: '$25.00')

      result = helper.render_money_column(money, column)

      expect(result).to eq('$25.00')
    end
  end

  describe '#render_date_column' do
    let(:column) { Spree::Admin::Table::Column.new(key: 'date', label: :date, type: 'date') }

    it 'uses spree_date helper' do
      date = Date.new(2025, 12, 25)
      allow(helper).to receive(:spree_date).with(date).and_return('Dec 25, 2025')

      result = helper.render_date_column(date, column)

      expect(result).to eq('Dec 25, 2025')
    end

    it 'uses custom format method if specified' do
      column = Spree::Admin::Table::Column.new(key: 'date', label: :date, type: 'date', format: 'custom_date_format')
      allow(helper).to receive(:respond_to?).with('custom_date_format').and_return(true)
      allow(helper).to receive(:respond_to?).with(anything).and_call_original
      allow(helper).to receive(:custom_date_format).and_return('formatted date')

      result = helper.render_date_column(Date.today, column)

      expect(result).to eq('formatted date')
    end
  end

  describe '#render_datetime_column' do
    let(:column) { Spree::Admin::Table::Column.new(key: 'datetime', label: :datetime, type: 'datetime') }

    it 'uses spree_time_ago helper' do
      time = Time.current
      allow(helper).to receive(:spree_time_ago).with(time).and_return('5 minutes ago')

      result = helper.render_datetime_column(time, column)

      expect(result).to eq('5 minutes ago')
    end
  end

  describe '#render_status_column' do
    let(:column) { Spree::Admin::Table::Column.new(key: 'status', label: :status, type: 'status') }

    it 'applies correct CSS class for active statuses' do
      %w[active complete completed paid shipped available].each do |status|
        result = helper.render_status_column(status, column)
        expect(result).to include('badge-active'), "Expected badge-active for #{status}"
      end
    end

    it 'applies correct CSS class for warning statuses' do
      %w[draft pending processing ready].each do |status|
        result = helper.render_status_column(status, column)
        expect(result).to include('badge-warning'), "Expected badge-warning for #{status}"
      end
    end

    it 'applies correct CSS class for inactive statuses' do
      %w[archived canceled cancelled failed void inactive].each do |status|
        result = helper.render_status_column(status, column)
        expect(result).to include('badge-inactive'), "Expected badge-inactive for #{status}"
      end
    end

    it 'applies secondary class for unknown statuses' do
      result = helper.render_status_column('custom', column)
      expect(result).to include('badge-secondary')
    end
  end

  describe '#render_string_column' do
    let(:column) { Spree::Admin::Table::Column.new(key: 'name', label: :name, type: 'string') }

    it 'escapes HTML in value' do
      result = helper.render_string_column('<script>alert("xss")</script>', column)

      expect(result).not_to include('<script>')
      expect(result).to include('&lt;script&gt;')
    end

    it 'truncates to 100 characters' do
      long_string = 'A' * 150
      result = helper.render_string_column(long_string, column)

      expect(result.length).to be < 150
    end
  end

  describe '#column_header_class' do
    it 'returns empty string for left-aligned column (default)' do
      column = Spree::Admin::Table::Column.new(key: 'name', label: :name, align: 'left')

      result = helper.column_header_class(column)

      expect(result).to eq('')
    end

    it 'returns text alignment class for right alignment' do
      column = Spree::Admin::Table::Column.new(key: 'price', label: :price, align: 'right')

      result = helper.column_header_class(column)

      expect(result).to include('text-right')
    end

    it 'includes width class when specified' do
      column = Spree::Admin::Table::Column.new(key: 'status', label: :status, width: '100')

      result = helper.column_header_class(column)

      expect(result).to include('w-100')
    end
  end

  describe '#column_cell_class' do
    it 'returns empty string for left-aligned column (default)' do
      column = Spree::Admin::Table::Column.new(key: 'name', label: :name, align: 'left')

      result = helper.column_cell_class(column)

      expect(result).to eq('')
    end

    it 'returns text alignment class for right alignment' do
      column = Spree::Admin::Table::Column.new(key: 'price', label: :price, align: 'right')

      result = helper.column_cell_class(column)

      expect(result).to include('text-right')
    end
  end

  describe '#count_applied_filters' do
    it 'returns 0 for blank query state' do
      expect(helper.count_applied_filters(nil)).to eq(0)
      expect(helper.count_applied_filters('')).to eq(0)
      expect(helper.count_applied_filters('{}')).to eq(0)
    end

    it 'counts filters at top level' do
      query_state = {
        'filters' => [
          { 'field' => 'name', 'operator' => 'cont', 'value' => 'test' },
          { 'field' => 'status', 'operator' => 'eq', 'value' => 'active' }
        ]
      }.to_json

      expect(helper.count_applied_filters(query_state)).to eq(2)
    end

    it 'does not count filters without field' do
      query_state = {
        'filters' => [
          { 'field' => 'name', 'operator' => 'cont', 'value' => 'test' },
          { 'field' => '', 'operator' => '', 'value' => '' }
        ]
      }.to_json

      expect(helper.count_applied_filters(query_state)).to eq(1)
    end

    it 'counts filters in nested groups' do
      query_state = {
        'filters' => [
          { 'field' => 'name', 'operator' => 'cont', 'value' => 'test' }
        ],
        'groups' => [
          {
            'filters' => [
              { 'field' => 'status', 'operator' => 'eq', 'value' => 'active' },
              { 'field' => 'price', 'operator' => 'gt', 'value' => '10' }
            ]
          }
        ]
      }.to_json

      expect(helper.count_applied_filters(query_state)).to eq(3)
    end

    it 'returns 0 for invalid JSON' do
      expect(helper.count_applied_filters('invalid json')).to eq(0)
    end
  end

  describe '#query_builder_fields_json' do
    it 'returns JSON string of available fields' do
      result = helper.query_builder_fields_json(table)

      parsed = JSON.parse(result)
      expect(parsed).to be_an(Array)
    end
  end

  describe '#query_builder_operators_json' do
    it 'returns JSON string of available operators' do
      result = helper.query_builder_operators_json

      parsed = JSON.parse(result)
      expect(parsed).to be_an(Array)
      expect(parsed.first).to have_key('value')
      expect(parsed.first).to have_key('label')
    end
  end

  describe '#render_bulk_action' do
    let(:action) do
      Spree::Admin::Table::BulkAction.new(
        key: :delete,
        label: 'Delete',
        icon: 'trash',
        modal_path: '/admin/bulk/delete',
        action_path: '/admin/products/bulk_delete'
      )
    end

    before do
      allow(helper).to receive(:icon).and_return('<svg></svg>'.html_safe)
    end

    it 'renders link with action data attributes' do
      result = helper.render_bulk_action(action)

      expect(result).to include('Delete')
      expect(result).to include('href="/admin/bulk/delete"')
      expect(result).to include('data-action')
      expect(result).to include('bulk-operation#setBulkAction')
    end

    it 'includes icon when present' do
      result = helper.render_bulk_action(action)

      expect(helper).to have_received(:icon).with('trash')
    end

    it 'returns nil when action is not visible' do
      action = Spree::Admin::Table::BulkAction.new(
        key: :delete,
        label: 'Delete',
        condition: false
      )

      result = helper.render_bulk_action(action)

      expect(result).to be_nil
    end

    it 'includes confirm data attribute when present' do
      action = Spree::Admin::Table::BulkAction.new(
        key: :delete,
        label: 'Delete',
        modal_path: '/admin/bulk/delete',
        confirm: 'Are you sure?'
      )

      result = helper.render_bulk_action(action)

      expect(result).to include('data-confirm="Are you sure?"')
    end
  end

  describe '#render_bulk_actions_panel' do
    before do
      allow(helper).to receive(:bulk_operations_counter).and_return('<span>0 selected</span>'.html_safe)
      allow(helper).to receive(:bulk_operations_close_button).and_return('<button>Close</button>'.html_safe)
      allow(helper).to receive(:icon).and_return('<svg></svg>'.html_safe)
    end

    it 'returns nil when no bulk actions' do
      result = helper.render_bulk_actions_panel(table)

      expect(result).to be_nil
    end

    it 'renders panel with bulk actions' do
      table.add_bulk_action(:delete, label: 'Delete', modal_path: '/delete')

      result = helper.render_bulk_actions_panel(table)

      expect(result).to include('bulk-panel')
      expect(result).to include('Delete')
    end

    it 'renders first 2 actions as primary' do
      table.add_bulk_action(:delete, label: 'Delete', modal_path: '/delete', position: 10)
      table.add_bulk_action(:export, label: 'Export', modal_path: '/export', position: 20)

      result = helper.render_bulk_actions_panel(table)

      expect(result).to include('Delete')
      expect(result).to include('Export')
    end
  end

  describe 'private methods' do
    describe '#parse_current_sort' do
      it 'returns [nil, nil] for blank sort' do
        result = helper.send(:parse_current_sort, nil)
        expect(result).to eq([nil, nil])

        result = helper.send(:parse_current_sort, '')
        expect(result).to eq([nil, nil])
      end

      it 'parses field and direction' do
        result = helper.send(:parse_current_sort, 'name asc')
        expect(result).to eq(['name', 'asc'])

        result = helper.send(:parse_current_sort, 'created_at desc')
        expect(result).to eq(['created_at', 'desc'])
      end
    end

    describe '#find_sort_label' do
      it 'returns default label for blank sort' do
        sortable = table.sortable_columns

        result = helper.send(:find_sort_label, sortable, nil)

        expect(result).to eq(Spree.t('admin.tables.sort_by'))
      end

      it 'returns column label when found' do
        sortable = table.sortable_columns

        result = helper.send(:find_sort_label, sortable, 'name asc')

        expect(result).to eq(Spree.t(:name))
      end

      it 'returns default label when column not found' do
        sortable = table.sortable_columns

        result = helper.send(:find_sort_label, sortable, 'unknown asc')

        expect(result).to eq(Spree.t('admin.tables.sort_by'))
      end
    end

    describe '#count_filters_in_state' do
      it 'returns 0 for non-hash state' do
        expect(helper.send(:count_filters_in_state, nil)).to eq(0)
        expect(helper.send(:count_filters_in_state, 'string')).to eq(0)
        expect(helper.send(:count_filters_in_state, [])).to eq(0)
      end

      it 'counts filters with field present' do
        state = {
          'filters' => [
            { 'field' => 'name' },
            { 'field' => '' },
            { 'field' => 'status' }
          ]
        }

        expect(helper.send(:count_filters_in_state, state)).to eq(2)
      end

      it 'recursively counts in nested groups' do
        state = {
          'filters' => [{ 'field' => 'name' }],
          'groups' => [
            { 'filters' => [{ 'field' => 'status' }] },
            { 'filters' => [{ 'field' => 'price' }], 'groups' => [{ 'filters' => [{ 'field' => 'quantity' }] }] }
          ]
        }

        expect(helper.send(:count_filters_in_state, state)).to eq(4)
      end
    end
  end
end
