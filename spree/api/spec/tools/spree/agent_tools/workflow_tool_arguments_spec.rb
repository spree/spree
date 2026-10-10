require 'spec_helper'

# A workflow tool's arguments arrive as JSON, so every record it is meant to
# act on comes in as a prefixed id. What the tool does between receiving those
# strings and calling the workflow is the whole of its contract.
RSpec.describe 'agent workflow tool arguments' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }

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
  # A workflow assigns the attributes hash it is handed, and some assign it
  # after setting tenancy. The tool is the trust boundary, so an attribute the
  # Admin API would not permit must never reach the workflow.
  describe 'an attribute the Admin API does not permit' do
    let(:other_store) { create(:store) }

    it 'is refused by name on create rather than written' do
      result = tool('products_create').call(
        attributes: { 'name' => 'Tenancy probe', 'store_id' => other_store.id }
      )

      expect(result[:error]).to include('store_id')
      expect(Spree::Product.where(name: 'Tenancy probe')).to be_empty
    end

    # Worse than a create: this would move an existing product out of the
    # store that owns it, which the owning merchant sees as data loss.
    it 'cannot move an existing record to another store' do
      product = create(:product, store: store)

      result = tool('products_update').call(
        product: product.prefixed_id, attributes: { 'store_id' => other_store.id }
      )

      expect(result[:error]).to include('store_id')
      expect(product.reload.store_id).to eq(store.id)
    end
  end

  # Nothing shipped reaches this, but an extension registering a workflow
  # whose key does not name a Spree model would: `can?(:create, nil)` answers
  # true, so the authorization check passes for exactly the tool nobody can
  # vouch for, and the attribute filter keyed off the same lookup falls open
  # with it.
  describe 'a workflow naming a resource that does not exist' do
    let(:tool_class) do
      Spree::AgentTools::WorkflowTool.for(:product_create_workflow, permission: 'write_products')
    end

    let(:tool) do
      instance = tool_class.new(context)
      allow(instance).to receive(:created_model).and_return(nil)
      allow(instance).to receive(:subject_model).and_return(nil)
      instance
    end

    it 'refuses rather than authorizing against nothing' do
      result = tool.call(attributes: { 'name' => 'Should not be created' })

      expect(result[:error]).to include('does not exist').or include('not one an agent may write')
      expect(Spree::Product.where(name: 'Should not be created')).to be_empty
    end
  end

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
      admin_context = Spree::AgentTools::Context.new(store: store, user: admin, request_headers: agent_headers_for(admin))
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
