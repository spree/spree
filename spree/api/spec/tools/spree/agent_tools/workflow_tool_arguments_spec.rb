require 'spec_helper'

# A workflow tool's arguments arrive as JSON, so every record it is meant to
# act on comes in as a prefixed id. What the tool does between receiving those
# strings and calling the workflow is the whole of its contract.
RSpec.describe 'agent workflow tool arguments' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key) }

  def tool(name)
    Spree.agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'records named inside a list of rows' do
    let(:supplier) { create(:supplier, store: store) }
    let(:stock_location) { store.stock_locations.first || create(:stock_location, store: store) }
    let(:variant) { create(:variant) }

    # A purchase order's `items:` names a variant per row. Left as a string
    # the association is handed a prefixed id and the record fails with
    # "must exist", which reads to the model as a bad id rather than a step
    # the tool skipped.
    it 'resolves them to records' do
      result = tool('purchase_orders_create').call(
        supplier: supplier.prefixed_id,
        destination_location: stock_location.prefixed_id,
        items: [{ 'variant' => variant.prefixed_id, 'quantity_ordered' => 2, 'unit_cost' => 5 }]
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.items.first.variant).to eq(variant)
    end

    it 'names the row and the field when an id matches nothing' do
      result = tool('purchase_orders_create').call(
        supplier: supplier.prefixed_id,
        destination_location: stock_location.prefixed_id,
        items: [{ 'variant' => 'variant_nope', 'quantity_ordered' => 1, 'unit_cost' => 1 }]
      )

      expect(result[:error]).to include('variant', 'items')
    end
  end

  # Several models still declare `created_by` as a plain belongs_to on the
  # admin-user class rather than through `acted_by`. Handing one an API key
  # raises inside the workflow, where the honest outcome is an unattributed
  # record.
  describe 'an actor the record cannot hold' do
    let(:supplier) { create(:supplier, store: store) }
    let(:stock_location) { store.stock_locations.first || create(:stock_location, store: store) }
    let(:variant) { create(:variant) }

    it 'leaves it unset rather than failing the call' do
      result = tool('purchase_orders_create').call(
        supplier: supplier.prefixed_id,
        destination_location: stock_location.prefixed_id,
        items: [{ 'variant' => variant.prefixed_id, 'quantity_ordered' => 1, 'unit_cost' => 3 }]
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.created_by).to be_nil
    end

    it 'records an admin user, which the association does accept' do
      admin = create(:admin_user)
      admin_context = Spree::AgentTools::Context.new(store: store, user: admin)
      admin_tool = Spree.agent_tools.available_for(admin_context).
                   find { |candidate| candidate.tool_name == 'purchase_orders_create' }

      result = admin_tool.call(
        supplier: supplier.prefixed_id,
        destination_location: stock_location.prefixed_id,
        items: [{ 'variant' => variant.prefixed_id, 'quantity_ordered' => 1, 'unit_cost' => 3 }]
      )

      expect(result[:error]).to be_nil
      expect(store.purchase_orders.last.created_by).to eq(admin)
    end
  end
end
