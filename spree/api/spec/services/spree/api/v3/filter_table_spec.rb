require 'spec_helper'
require 'spree/api/openapi/filter_documentation'

RSpec.describe Spree::Api::V3::FilterTable do
  after { described_class.reset! }

  describe 'every list endpoint' do
    let(:list_controllers) do
      Rails.application.eager_load!
      Spree::Core::Engine.routes.routes.filter_map do |route|
        next unless route.defaults[:action] == 'index' && route.defaults[:controller].to_s.start_with?('spree/api/v3')

        controller = "#{route.defaults[:controller]}_controller".camelize.safe_constantize
        controller if controller && controller < Spree::Api::V3::ResourceController
      end.uniq
    end

    it 'builds a table whose attributes all have a value kind' do
      unclassified = {}

      list_controllers.each do |controller|
        endpoint = described_class.for(controller)
        next unless endpoint.filterable?

        endpoint.to_h
        # Every search needs a description in the reference.
        Spree::Api::OpenAPI::FilterDocumentation.new(
          endpoint, querying_path: '/', search: FilterParametersHelper::SEARCH_DESCRIPTIONS[endpoint.table.name]
        ).parameters
        endpoint.tables.each do |name, table|
          table.to_h
          unclassified[name] = table.unclassified_attributes if table.unclassified_attributes.any?
        end
      end

      expect(unclassified).to be_empty
    end
  end

  describe '#to_h' do
    subject(:table) { described_class.for_model(Spree::Order, nil).to_h }

    it 'reads each value kind from the column, its validations and its associations' do
      expect(table['attributes']).to include(
        'number' => 'text',
        'total' => 'decimal',
        'total_quantity' => 'integer',
        'completed_at' => 'datetime',
        'considered_risky' => 'boolean',
        'customer_id' => 'id',
        'id' => 'id',
        'status' => { 'enum' => Spree::Order::STATUSES }
      )
    end

    it 'names associated tables instead of nesting them' do
      expect(table['associations']).to include('line_items' => 'LineItem', 'customer' => 'Customer')
    end

    it 'publishes declared scope types and infers the rest' do
      expect(table['scopes']).to include('complete' => 'boolean', 'search' => 'text')
      expect(described_class.for_model(Spree::Product, nil).scopes).to include(
        'price_between' => %w[decimal decimal],
        'in_categories' => { 'list' => 'id' },
        'in_stock' => 'boolean'
      )
    end

    it 'publishes polymorphic type columns as short names' do
      expect(described_class.for_model(Spree::StockReceipt, nil).attributes).to include('receivable_type' => 'type')
    end

    it 'refuses a scope type outside the contract' do
      allow(Spree::Order).to receive(:ransackable_scope_types).and_return('search' => 'money')

      expect { table }.to raise_error(described_class::Error, /unknown kind "money"/)
    end
  end

  describe 'audiences' do
    it 'leaves private attributes and back-office associations out of the Store table' do
      store_table = described_class.for_model(Spree::Variant, :store)

      expect(store_table.associations.keys).to match_array(Spree::Variant.storefront_ransackable_associations.map(&:to_s))
      expect(store_table.attributes.keys).not_to include('cost_price', 'cost_currency', 'deleted_at')
      expect(described_class.for_model(Spree::Variant, nil).attributes.keys).to include('cost_price')
    end

    it 'gives the Seller table no associations' do
      expect(described_class.for_model(Spree::Order, :seller).associations).to be_empty
    end
  end

  describe '#reachable' do
    it 'stops two hops from the root table' do
      order = described_class.for_model(Spree::Order, nil)
      depth_two = order.associations.values.flat_map { |table| table.associations.values }.map(&:name)
      depth_three_only = depth_two.flat_map { |name| order.reachable[name].associations.values.map(&:name) } -
                         depth_two - order.associations.values.map(&:name) - ['Order']

      expect(order.reachable.keys).to include('Order', 'LineItem', *depth_two)
      expect(order.reachable.keys).not_to include(*depth_three_only)
    end
  end

  describe '.for' do
    it 'adds what a product list accepts beyond the model' do
      endpoint = described_class.for(Spree::Api::V3::Store::ProductsController).to_h

      expect(endpoint).to include('table' => 'Product', 'custom_fields' => true)
      expect(endpoint['sortable']).to include('price', 'best_selling', 'manual', 'name')
    end

    it 'skips a list that does not filter' do
      expect(described_class.for(Spree::Api::V3::Admin::CountriesController)).not_to be_filterable
    end
  end
end
