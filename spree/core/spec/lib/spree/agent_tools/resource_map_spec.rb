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
end
