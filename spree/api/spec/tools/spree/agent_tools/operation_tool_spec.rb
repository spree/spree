require 'spec_helper'

# An action tool is an Admin API operation: its name, prose and arguments come
# from the OpenAPI document, and a call is a request to the endpoint. See
# docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.describe Spree::AgentTools::OperationTool do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }
  let(:names) { Spree::AgentTools::OperationCatalog.all.map(&:name) }

  def tool(name)
    Spree.admin_agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  def every_schema
    catalog = Spree::AgentTools::OperationCatalog
    (catalog.all + catalog.aliases).map(&:input_schema)
  end

  describe 'the catalog' do
    it 'offers a tool for each non-CRUD admin write' do
      expect(names).to include('orders_cancel', 'payments_capture', 'sellers_approve', 'stock_transfers_mark_ready')
    end

    # Creates of a resource that lives under two parents, which the generic
    # create cannot choose between, named explicitly.
    it 'offers a create that names its tool' do
      expect(names).to include('stock_transfers_receive', 'purchase_orders_receive', 'shipping_labels_purchase')
    end

    it 'no longer answers to deliveries_update_tracking, which marked a delivery delivered' do
      expect(Spree.admin_agent_tools.find_for('deliveries_update_tracking', context)).to be_nil
    end

    it 'offers the product status moves, which now have endpoints' do
      expect(names).to include('products_activate', 'products_archive', 'products_draft')
    end

    it 'leaves plain create, update and destroy to the generic tools' do
      expect(names).not_to include('products_create', 'products_update', 'orders_destroy')
    end

    it 'leaves out an operation its spec opts out' do
      expect(names).not_to include('customers_anonymize', 'products_bulk_destroy', 'stock_levels_bulk_upsert')
    end

    it 'gates each tool with its controller\'s write scope' do
      expect(Spree::AgentTools::OperationCatalog.find('payments_capture').permission).to eq('write_payments')
      expect(Spree::AgentTools::OperationCatalog.find('orders_cancel').permission).to eq('write_orders')
    end

    it 'describes a tool in the operation\'s own words' do
      expect(tool('orders_cancel').description).to start_with('Cancel an order. Cancels a completed order.')
    end

    it 'offers nothing to a key without the scope' do
      reader = create(:api_key, :secret, store: store, scopes: ['read_orders'])
      reader_context = Spree::AgentTools::Context.new(store: store, api_key: reader,
                                                      request_headers: agent_headers_for_key(reader))

      offered = Spree.admin_agent_tools.available_for(reader_context).map(&:tool_name)

      expect(offered).not_to include('orders_cancel')
    end
  end

  describe 'the input schema' do
    it 'is the path segments beside the request body' do
      properties = tool('orders_cancel').class.input_schema['properties']

      expect(properties.keys).to include('id', 'cancel_reason_id', 'cancel_note', 'notify_customer')
    end

    it 'keeps a segment required when it is the record the call is about' do
      expect(tool('catalog_quantity_rules_upsert').class.input_schema['required']).to include('catalog_id')
    end

    it 'carries a nested body shape whole' do
      prices = tool('prices_bulk_upsert').class.input_schema.dig('properties', 'prices')

      expect(prices['type']).to eq('array')
      expect(prices.dig('items', 'properties')).to include('variant_id', 'amount')
    end

    it 'is plain JSON Schema, with no reference or OpenAPI-only keyword left in it' do
      serialized = JSON.generate(every_schema)

      expect(serialized).not_to include('$ref', '"nullable"')
    end
  end

  describe 'a call' do
    it 'runs the operation through its endpoint' do
      order = create(:order_ready_to_ship, store: store)

      result = tool('orders_cancel').call(id: order.prefixed_id, cancel_note: 'Duplicate order')

      expect(result[:error]).to be_nil
      expect(order.reload.status).to eq('canceled')
      expect(result[:summary]).to eq("Cancel an order #{order.number}")
    end

    it 'does not reach a record in another store' do
      theirs = create(:order_ready_to_ship, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      result = tool('orders_cancel').call(id: theirs.prefixed_id)

      expect(result[:error]).to be_present
      expect(theirs.reload.status).not_to eq('canceled')
    end

    # The caller named the payment; the order it belongs to follows from it.
    it 'reads a parent segment off the record the call names' do
      order = create(:order_with_line_items, store: store)
      payment = create(:payment, order: order, amount: 10)

      result = tool('payments_void').call(id: payment.prefixed_id)

      expect(result[:error]).to be_nil
      expect(payment.reload.status).to eq('void')
    end

    it 'names back an argument the operation does not take' do
      order = create(:order_ready_to_ship, store: store)

      result = tool('orders_cancel').call(id: order.prefixed_id, reason_code: 'duplicate')

      expect(result[:error]).to include('reason_code')
      expect(result[:accepted_arguments]).to include('cancel_reason_id')
      expect(order.reload.status).not_to eq('canceled')
    end

    it 'asks for a segment it was not given' do
      expect(tool('orders_cancel').call[:error]).to include('needs id')
    end

    it 'moves a product through its status workflow' do
      product = create(:product, store: store, status: 'active')

      result = tool('products_draft').call(id: product.prefixed_id)

      expect(result[:error]).to be_nil
      expect(product.reload.status).to eq('draft')
    end

    it 'approves a seller it created when told to override, and can then suspend it' do
      created = tool('create_resource').call(resource: 'sellers', attributes: { name: 'Biuro Plus' })
      seller = store.sellers.find_by!(name: 'Biuro Plus')
      expect(created[:error]).to be_nil
      expect(seller).to be_pending

      approved = tool('sellers_approve').call(id: seller.prefixed_id, override_requirements: true)
      expect(approved[:error]).to be_nil
      expect(seller.reload).to be_approved

      suspended = tool('sellers_suspend').call(id: seller.prefixed_id, reason: 'Counterfeit goods')
      expect(suspended[:error]).to be_nil
      expect(seller.reload).to be_suspended
    end

    it 'shows the operation and its record before running' do
      expect(tool('orders_cancel').summary(id: 'or_123')).to eq('Cancel an order or_123')
    end
  end

  # A read becomes a tool only when its spec opts it in; it then answers
  # with what it read and takes its arguments as the query.
  describe 'an opted-in read' do
    let(:entry) do
      Spree::AgentTools::OperationCatalog::Entry.new(
        name: 'promotion_rules_types', verb: 'get', path: '/api/v3/admin/promotion_rules/types',
        description: 'List promotion rule types', summary: 'List promotion rule types',
        permission: 'read_promotions', resource_key: 'promotion_rules', path_params: [],
        body_properties: {}, body_required: [], path_descriptions: {},
        listed: true, legacy_parameters: {}
      )
    end

    it 'returns the data the endpoint answered with' do
      result = described_class.for(entry).new(context).call

      expect(result[:error]).to be_nil
      expect(result[:data]).to be_present
    end
  end

  describe 'describe_resource' do
    it 'names the parent a resource is written under' do
      described = tool('describe_resource').call(resource: 'variants')

      expect(described[:resources].first[:parent]).to eq('products')
    end
  end

  # The 6.0.0 tools took a workflow's keywords. Through 6.0.x those calls keep
  # working, and the result says what to send instead.
  describe 'a call written for 6.0.0' do
    it 'maps a renamed parameter and says so' do
      order = create(:order_ready_to_ship, store: store)
      reason = store.order_cancellation_reasons.first || create(:order_cancellation_reason, store: store)

      result = tool('orders_cancel').call(order: order.prefixed_id, reason: reason.prefixed_id)

      expect(result[:error]).to be_nil
      expect(order.reload.cancel_reason_id).to eq(reason.id)
      expect(result[:deprecations]).to include('order is deprecated: use id.',
                                               'reason is deprecated: use cancel_reason_id.')
    end

    it 'keeps the note about an old name when the call is refused' do
      result = tool('orders_cancel').call(order: 'or_nope')

      expect(result[:error]).to be_present
      expect(result[:deprecations]).to include('order is deprecated: use id.')
    end

    it 'ignores a parameter the endpoint never read, and says so' do
      order = create(:order_ready_to_ship, store: store)

      result = tool('orders_cancel').call(order: order.prefixed_id, canceled_at: Time.current.iso8601)

      expect(result[:error]).to be_nil
      expect(result[:deprecations]).to include(a_string_including('canceled_at', 'ignored'))
    end

    it 'still answers to a name no longer listed' do
      product = create(:product, store: store)
      sku = "SKU-#{SecureRandom.hex(3)}"

      old = Spree.admin_agent_tools.find_for('variants_create', context)
      result = old.call(product: product.prefixed_id, attributes: { 'sku' => sku })

      expect(names).not_to include('variants_create')
      expect(result[:error]).to be_nil
      expect(Spree::Variant.where(sku: sku)).to exist
    end

    it 'ignores an attributes argument that is not a hash, and says so' do
      product = create(:product, store: store)

      old = Spree.admin_agent_tools.find_for('variants_create', context)
      result = old.call(product: product.prefixed_id, attributes: '{"sku":"X1"}')

      expect(result[:deprecations]).to include(a_string_including('attributes', 'ignored'))
    end

    it 'names the record on the approval line when called by old names' do
      expect(tool('orders_cancel').summary(order: 'or_123')).to eq('Cancel an order or_123')
    end

    it 'fills a parent segment from the record an old parameter named' do
      order = create(:order_ready_to_ship, store: store)

      old = Spree.admin_agent_tools.find_for('shipping_labels_purchase', context)
      result = old.call(owner: order.fulfillments.first.prefixed_id)

      # The provider refuses in test, which is the endpoint answering — an
      # unfilled segment would have been refused before the request.
      expect(result[:error]).not_to match(/needs|not found/i)
    end
  end

  describe 'Registry#expose_workflows' do
    it 'is deprecated and changes nothing' do
      registry = Spree::AgentTools::Registry.new(audience: :admin)
      allow(Spree::Deprecation).to receive(:warn)

      registry.expose_workflows(order_cancel_workflow: 'write_orders')

      expect(Spree::Deprecation).to have_received(:warn).with(a_string_including('expose_workflows is deprecated'))
      expect(registry.exposed_workflows.keys).to eq([:order_cancel_workflow])
    end
  end
end
