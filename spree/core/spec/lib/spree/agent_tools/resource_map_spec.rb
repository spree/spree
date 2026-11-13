require 'spec_helper'

# Core owns the map's structure; `spree_api` fills it. These register one entry
# by hand to check the gate the tools share, without the API engine.
RSpec.describe Spree::AgentTools::ResourceMap do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }

  def context_holding(*keys)
    Spree::AgentTools::Context.new(store: store, user: admin, granted_scopes: keys)
  end

  after { described_class.reset! }

  describe 'an entry opened by any of several keys' do
    let!(:entry) do
      described_class.register(key: 'exports', model_name: 'Spree::Export', permission: nil,
                               serializer_name: 'Spree::Export',
                               access_permissions: %w[read_products read_orders],
                               api_paths: { index: '/api/v3/admin/exports',
                                            show: '/api/v3/admin/exports/:id',
                                            destroy: '/api/v3/admin/exports/:id' })
    end

    it 'is readable by a caller holding any one of them' do
      expect(entry.readable_by?(context_holding('read_orders'))).to be(true)
      expect(entry.readable_by?(context_holding('read_products'))).to be(true)
    end

    it 'refuses a caller holding none of them' do
      expect(entry.readable_by?(context_holding('read_customers'))).to be(false)
      expect(described_class.available_for(context_holding('read_customers'))).to be_empty
    end

    it 'names every key that opens it' do
      expect(entry.permission_keys).to eq(%w[read_products read_orders])
    end

    # Each generic tool asks the entry rather than the context, so they agree
    # on who may reach the resource.
    it 'is refused by the generic tools for a caller holding none of them' do
      context = context_holding('read_customers', 'write_customers')

      expect(Spree::AgentTools::GetResource.new(context).call(resource: 'exports', id: 'exp_1')[:error]).
        to eq('You do not have permission to read exports.')
      expect(Spree::AgentTools::SearchResources.new(context).call(resource: 'exports')[:error]).
        to eq('You do not have permission to read exports.')
      expect(Spree::AgentTools::DeleteResource.new(context).call(resource: 'exports', id: 'exp_1')[:error]).
        to eq('You do not have permission to change exports.')
    end
  end

  describe 'an entry with one key' do
    let!(:entry) do
      described_class.register(key: 'products', model_name: 'Spree::Product', permission: 'read_products',
                               serializer_name: 'Spree::Product')
    end

    it 'is readable by exactly that key' do
      expect(entry.readable_by?(context_holding('read_products'))).to be(true)
      expect(entry.readable_by?(context_holding('read_orders'))).to be(false)
      expect(entry.permission_keys).to eq(['read_products'])
    end
  end

  # A search given parent_id runs on the collection under that parent; the
  # shallowest path alone listed the whole store.
  describe 'listing under a parent' do
    let(:base) { '/api/v3/admin' }
    let(:context) { context_holding('read_products', 'read_orders') }

    def register(key, model_name, permission, index_paths)
      described_class.register(key: key, model_name: model_name, permission: permission,
                               serializer_name: model_name, api_paths: { index: index_paths.first },
                               index_paths: index_paths)
    end

    let!(:products) do
      register('products', 'Spree::Product', 'read_products',
               ["#{base}/products", "#{base}/categories/:category_id/products",
                "#{base}/collections/:collection_id/products"])
    end
    let!(:claims) { register('claims', 'Spree::Claim', 'read_orders', ["#{base}/claims", "#{base}/orders/:order_id/claims"]) }
    let!(:deliveries) do
      register('deliveries', 'Spree::Delivery', 'read_orders',
               ["#{base}/orders/:order_id/fulfillments/:fulfillment_id/deliveries"])
    end

    before do
      register('categories', 'Spree::Category', 'read_products', ["#{base}/categories"])
      register('collections', 'Spree::Collection', 'read_products', ["#{base}/collections"])
      register('orders', 'Spree::Order', 'read_orders', ["#{base}/orders"])
    end

    it 'names the parents a resource is listed under' do
      expect(products.index_parents.keys).to eq(%w[categories collections])
    end

    it "picks the parent's collection by the id's prefix" do
      expect(products.path_for(:index, parent_id: 'ctg_abc')).to eq("#{base}/categories/ctg_abc/products")
      expect(products.path_for(:index, parent_id: 'coll_abc')).to eq("#{base}/collections/coll_abc/products")
    end

    it 'lists the whole collection without a parent' do
      expect(products.path_for(:index)).to eq("#{base}/products")
    end

    it 'has no path under a parent of another kind' do
      expect(products.path_for(:index, parent_id: 'or_abc')).to be_nil
    end

    it 'uses the only parent there is, leaving the id to the endpoint' do
      expect(claims.path_for(:index, parent_id: 'or_abc')).to eq("#{base}/orders/or_abc/claims")
    end

    it 'leaves out a path one parent id cannot fill' do
      expect(deliveries.index_parents).to be_empty
    end

    it 'refuses a search under a parent the resource is not listed under' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'products', parent_id: 'or_abc')

      expect(result[:error]).to eq('products cannot be listed under or_abc. Pass the id of one of: categories, collections.')
      expect(result[:parents]).to eq(%w[categories collections])
    end

    it 'refuses a parent for a resource never listed under one' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'orders', parent_id: 'prod_abc')

      expect(result[:error]).to include('not listed under another record')
    end

    it 'keeps the nested refusal for a resource two levels deep' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'deliveries', parent_id: 'or_abc')

      expect(result[:error]).not_to include('cannot be listed under')
    end

    it 'is named by describe_resource' do
      described = Spree::AgentTools::DescribeResource.new(context).call(resource: 'products')[:resources].first

      expect(described[:listed_under]).to eq(%w[categories collections])
    end
  end

  # What a write accepts, read per operation. The Admin API document is not
  # loaded here, so a stand-in answers for it with one product body.
  describe 'checking a write body' do
    let(:base) { '/api/v3/admin' }
    let(:context) { context_holding('read_products', 'write_products') }
    let(:price_row) { { 'properties' => { 'amount' => {}, 'currency' => {} } } }
    let(:variant_row) { { 'properties' => { 'sku' => {}, 'prices' => { 'type' => 'array', 'items' => price_row } } } }
    let(:product_body) do
      { 'name' => {},
        'variants' => { 'type' => 'array', 'items' => variant_row },
        'metadata_rows' => { 'type' => 'array', 'items' => { 'properties' => { 'key' => {} }, 'additionalProperties' => true } } }
    end
    let(:schemas) do
      body = product_body
      Module.new do
        define_singleton_method(:for_operation) { |path, _action| path.to_s.end_with?('/:id') ? body.except('variants') : body }
        define_singleton_method(:resolve_schema) { |schema, _depth = 0| schema }
      end
    end

    let!(:entry) do
      described_class.register(key: 'products', model_name: 'Spree::Product', permission: 'read_products',
                               serializer_name: 'Spree::Product', write_permission: 'write_products',
                               writable_attributes: { create: %w[name variants metadata_rows], update: %w[name metadata_rows] },
                               api_paths: { index: "#{base}/products", create: "#{base}/products",
                                            update: "#{base}/products/:id" })
    end

    before { stub_const('Spree::Api::AgentWriteSchemas', schemas) }

    def create_product(attributes)
      Spree::AgentTools::CreateResource.new(context).call(resource: 'products', attributes: attributes)
    end

    it 'lists what each write accepts, and both together' do
      expect(entry.writable_attribute_names(:update)).to eq(%w[metadata_rows name])
      expect(entry.writable_attribute_names).to eq(%w[metadata_rows name variants])
    end

    it 'takes a plain list for every write' do
      plain = described_class.register(key: 'markets', model_name: 'Spree::Market', permission: 'read_settings',
                                       serializer_name: 'Spree::Market', writable_attributes: %i[name])

      expect(plain.writable_attribute_names(:update)).to eq(['name'])
    end

    it 'refuses an attribute only a create takes' do
      result = Spree::AgentTools::UpdateResource.new(context).call(resource: 'products', id: 'prod_1',
                                                                   attributes: { 'variants' => [] })

      expect(result[:error]).to eq('products does not accept variants.')
      expect(result[:accepted_attributes]).to eq(%w[metadata_rows name])
    end

    it 'names a field inside rows inside rows' do
      result = create_product('variants' => [{ 'sku' => 'A', 'prices' => [{ 'amount' => '1.00', 'amount_typo' => '2' }] }])

      expect(result[:error]).to eq('products variants.prices rows do not accept amount_typo.')
      expect(result[:accepted_attributes]).to eq('variants.prices' => %w[amount currency])
    end

    it 'refuses a row that is not an object' do
      result = create_product('variants' => ['sku-a'])

      expect(result[:error]).to eq('products variants rows must each be an object.')
    end

    it 'leaves an open row alone' do
      expect(entry.unknown_row_fields({ 'metadata_rows' => [{ 'anything' => 1 }] }, :create)).to be_nil
    end

    it 'refuses a write whose operation documents no body' do
      bare = described_class.register(key: 'tags', model_name: 'Spree::Tag', permission: 'read_products',
                                      serializer_name: 'Spree::Tag', api_paths: { create: "#{base}/tags" })

      result = Spree::AgentTools::CreateResource.new(context).call(resource: 'tags', attributes: { 'name' => 'x' })

      expect(bare.writable_attribute_names(:create)).to be_empty
      expect(result[:error]).to eq('tags cannot be created this way — call describe_resource to see what can.')
    end

    it 'says what an update takes where it is less than a create' do
      described = Spree::AgentTools::DescribeResource.new(context).call(resource: 'products')[:resources].first

      expect(described[:writable_attributes]).to eq(%w[metadata_rows name variants])
      expect(described[:updatable_attributes]).to eq(%w[metadata_rows name])
      expect(described[:nested_attributes]['variants'].pluck('name')).to eq(%w[prices sku])
    end
  end
end
