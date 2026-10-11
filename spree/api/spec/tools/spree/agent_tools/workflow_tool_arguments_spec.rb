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
      admin_tool = Spree.agent_tools.available_for(admin_context).
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
  # A workflow with an endpoint runs through it: the controller's routing,
  # authentication, authorization and serializer, rather than a second copy
  # of each beside them.
  describe 'running through the endpoint' do
    it 'dispatches every workflow that has one' do
      in_process = Spree::AgentTools::DefaultCatalog::WORKFLOWS.reject do |key, _options|
        Spree::AgentTools::WorkflowEndpoints.find(key)
      end

      # Only the product status moves, which the Admin API does not expose:
      # `PATCH` writes the column and the bulk action uses `update_all`, so
      # neither publishes the event nor withdraws an open submission.
      expect(in_process.keys).to contain_exactly(
        :product_activate_workflow, :product_draft_workflow, :product_archive_workflow
      )
    end

    it 'fills a parent segment from the record the caller named' do
      order = create(:order_with_line_items, store: store)
      payment = create(:payment, order: order, amount: 10)

      result = tool('payments_void').call(payment: payment.prefixed_id)

      expect(result[:error]).to be_nil
      expect(payment.reload.status).to eq('void')
    end

    it 'sends a keyword under the name the endpoint documents' do
      order = create(:order_ready_to_ship, store: store)

      result = tool('orders_cancel').call(order: order.prefixed_id, cancel_note: 'Duplicate order')

      expect(result[:error]).to be_nil
      expect(order.reload.status).to eq('canceled')
    end

    it 'does not reach a record in another store' do
      theirs = create(:order_ready_to_ship, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      result = tool('orders_cancel').call(order: theirs.prefixed_id)

      expect(result[:error]).to be_present
      expect(theirs.reload.status).not_to eq('canceled')
    end
    # A keyword the endpoint carries under another name has to arrive, or the
    # tool reports a change it did not make. Three shapes caught real drops
    # while this was written: a record renamed by the action
    # (`reason:` -> `cancel_reason_id`), an attributes hash that IS the body,
    # and a keyword whose record fills a path segment of a different name.
    it 'sends a record the action renamed' do
      order = create(:order_ready_to_ship, store: store)
      reason = store.order_cancellation_reasons.first || create(:order_cancellation_reason, store: store)

      result = tool('orders_cancel').call(order: order.prefixed_id, reason: reason.prefixed_id)

      expect(result[:error]).to be_nil
      expect(order.reload.cancel_reason_id).to eq(reason.id)
    end

    it 'merges an attributes hash into the body' do
      product = create(:product, store: store)
      sku = "SKU-#{SecureRandom.hex(3)}"

      result = tool('variants_create').call(product: product.prefixed_id, attributes: { 'sku' => sku })

      expect(result[:error]).to be_nil
      expect(Spree::Variant.where(sku: sku)).to exist
    end

    it 'fills a path segment from a keyword of a different name' do
      order = create(:order_ready_to_ship, store: store)

      result = tool('shipping_labels_purchase').call(owner: order.fulfillments.first.prefixed_id)

      # The provider refuses in test, which is the endpoint answering — a
      # segment left unfilled would have been a 404 instead.
      expect(result[:error]).not_to match(/not found/i)
    end
  end
end
