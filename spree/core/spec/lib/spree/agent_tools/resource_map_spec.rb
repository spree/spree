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
end
