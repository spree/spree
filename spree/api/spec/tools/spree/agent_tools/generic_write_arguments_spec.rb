require 'spec_helper'

# A generic write's arguments arrive as JSON, so every record it is meant to
# act on comes in as a prefixed id, and every attribute is checked against what
# the endpoint permits before it is sent.
RSpec.describe 'agent generic write arguments' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }

  def tool(name)
    Spree.admin_agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'records named inside a list of rows' do
    let(:supplier) { create(:supplier, store: store) }
    let(:stock_location) { store.stock_locations.first || create(:stock_location, store: store) }
    let(:variant) { create(:variant) }

    # A purchase order's items name a variant per row. The ids inside those
    # rows have to be decoded too, not just the ones at the top level.
    it 'resolves them to records' do
      result = tool('create_resource').call(
        resource: 'purchase_orders',
        attributes: {
          'supplier_id' => supplier.prefixed_id,
          'destination_location_id' => stock_location.prefixed_id,
          'items' => [{ 'variant_id' => variant.prefixed_id, 'quantity_ordered' => 2,
                        'unit_cost' => '5.00' }]
        }
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.items.first.variant).to eq(variant)
    end

    it 'names what was not found when an id inside a row matches nothing' do
      result = tool('create_resource').call(
        resource: 'purchase_orders',
        attributes: {
          'supplier_id' => supplier.prefixed_id,
          'destination_location_id' => stock_location.prefixed_id,
          'items' => [{ 'variant_id' => 'variant_nope', 'quantity_ordered' => 1,
                        'unit_cost' => '1.00' }]
        }
      )

      expect(result[:error]).to include('Variant')
      expect(store.purchase_orders).to be_empty
    end
  end

  # Several models still declare `created_by` as a plain belongs_to on the
  # admin-user class rather than through `acted_by`. Handing one an API key
  # raises inside the workflow, where the honest outcome is an unattributed
  # record.
  # A workflow assigns the attributes hash it is handed, and some assign it
  # after setting tenancy. The tool is the trust boundary, so an attribute the
  # Admin API would not permit must never reach the workflow.
  describe 'an attribute the Admin API does not permit' do
    let(:other_store) { create(:store) }

    it 'is refused by name on create rather than written' do
      result = tool('create_resource').call(
        resource: 'products', attributes: { 'name' => 'Tenancy probe', 'store_id' => other_store.id }
      )

      expect(result[:error]).to include('store_id')
      expect(Spree::Product.where(name: 'Tenancy probe')).to be_empty
    end

    # Worse than a create: this would move an existing product out of the
    # store that owns it, which the owning merchant sees as data loss.
    it 'cannot move an existing record to another store' do
      product = create(:product, store: store)

      result = tool('update_resource').call(
        resource: 'products', id: product.prefixed_id, attributes: { 'store_id' => other_store.id }
      )

      expect(result[:error]).to include('store_id')
      expect(product.reload.store_id).to eq(store.id)
    end
  end

  describe 'an actor the record cannot hold' do
    let(:supplier) { create(:supplier, store: store) }
    let(:stock_location) { store.stock_locations.first || create(:stock_location, store: store) }
    let(:variant) { create(:variant) }

    it 'leaves it unset rather than failing the call' do
      result = tool('create_resource').call(
        resource: 'purchase_orders',
        attributes: {
          'supplier_id' => supplier.prefixed_id,
          'destination_location_id' => stock_location.prefixed_id,
          'items' => [{ 'variant_id' => variant.prefixed_id, 'quantity_ordered' => 1,
                        'unit_cost' => '3.00' }]
        }
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.created_by).to be_nil
    end

    it 'records an admin user, which the association does accept' do
      admin = create(:admin_user)
      admin_context = Spree::AgentTools::Context.new(store: store, user: admin, request_headers: agent_headers_for(admin))
      admin_tool = Spree.admin_agent_tools.available_for(admin_context).
                   find { |candidate| candidate.tool_name == 'create_resource' }

      result = admin_tool.call(
        resource: 'purchase_orders',
        attributes: {
          'supplier_id' => supplier.prefixed_id,
          'destination_location_id' => stock_location.prefixed_id,
          'items' => [{ 'variant_id' => variant.prefixed_id, 'quantity_ordered' => 1,
                        'unit_cost' => '3.00' }]
        }
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.created_by).to eq(admin)
    end
  end
end
