require 'spec_helper'

# The registry is a public extension point, and
# docs/developer/agentic/admin-mcp.mdx tells an author to write exactly this
# tool. Documentation that does not compile is worse than none, so the example
# is pinned here — change one and this fails until the other follows.
RSpec.describe 'the extension path the docs describe' do
  let(:store) { @default_store }
  let(:key) { create(:api_key, :secret, store: store, scopes: ['read_purchasing']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: key) }

  before do
    stub_const('MyShop', Module.new)
    stub_const('MyShop::AgentTools', Module.new)
    stub_const('MyShop::AgentTools::SupplierStock', Class.new(Spree::AgentTool) do
      tool_name 'supplier_stock'
      description 'Current stock at a supplier, by SKU.'
      permission 'read_purchasing'
      param :sku, description: 'The SKU to look up', required: true

      def call(sku:)
        stock = { 'BS-1' => 42 }[sku]
        return { error: "No supplier carries #{sku}." } if stock.nil?

        { summary: "#{sku}: #{stock} available", sku: sku, available: stock }
      end
    end)
    Spree.agent_tools << 'MyShop::AgentTools::SupplierStock'
  end

  it 'is offered to a key holding the permission' do
    names = Spree.agent_tools.available_for(context).map(&:tool_name)
    expect(names).to include('supplier_stock')
  end

  it 'answers and refuses as documented' do
    tool = Spree.agent_tools.available_for(context).find { |t| t.tool_name == 'supplier_stock' }
    expect(tool.call(sku: 'BS-1')[:summary]).to eq('BS-1: 42 available')
    expect(tool.call(sku: 'NOPE')[:error]).to include('NOPE')
  end

  it 'is hidden from a key without the permission' do
    other = create(:api_key, :secret, store: store, scopes: ['read_products'])
    ctx = Spree::AgentTools::Context.new(store: store, api_key: other)

    expect(Spree.agent_tools.available_for(ctx).map(&:tool_name)).not_to include('supplier_stock')
  end
end
