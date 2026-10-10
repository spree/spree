require 'spec_helper'

# Cancelling and completing an order reach an agent through the workflow
# allowlist. Creating one is a service, so it is a written tool — and the gap
# showed up in use: an agent could make the customer but not the order.
RSpec.describe 'agent draft order creation' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }
  let(:product) { create(:product, store: store, status: 'active') }
  let(:variant) { product.variants.first || create(:variant, product: product) }

  def tool(ctx = context)
    Spree.agent_tools.available_for(ctx).find { |candidate| candidate.tool_name == 'orders_create' }
  end

  describe 'creating one' do
    it 'leaves a draft for the merchant to review' do
      result = tool.call(email: 'buyer@example.com',
                         items: [{ variant_id: variant.prefixed_id, quantity: 3 }])

      expect(result[:error]).to be_nil
      expect(result[:status]).to eq('draft')
      expect(result[:item_count]).to eq(3)

      order = store.orders.find_by_prefix_id(result[:id])
      expect(order.line_items.sum(&:quantity)).to eq(3)
      expect(order.email).to eq('buyer@example.com')
    end

    it 'orders for an existing customer' do
      customer = create(:customer)

      result = tool.call(customer_id: customer.prefixed_id,
                         items: [{ variant_id: variant.prefixed_id, quantity: 1 }])

      expect(result[:error]).to be_nil
      expect(store.orders.find_by_prefix_id(result[:id]).customer).to eq(customer)
    end

    # Who asked matters later, on the order's own record.
    it 'records the credential that asked as the creator' do
      result = tool.call(email: 'buyer@example.com', items: [{ variant_id: variant.prefixed_id }])

      expect(store.orders.find_by_prefix_id(result[:id]).created_by).to eq(api_key)
    end

    it 'defaults a line with no quantity to one' do
      result = tool.call(email: 'buyer@example.com', items: [{ variant_id: variant.prefixed_id }])

      expect(result[:item_count]).to eq(1)
    end
  end

  # The mistake a model makes most: a product has variants, and only a variant
  # can be ordered. Answering with the choices is what lets it correct itself
  # in one step instead of asking the merchant.
  describe 'given a product where a variant belongs' do
    it 'names the variants to choose between' do
      create(:variant, product: product)

      result = tool.call(email: 'buyer@example.com', items: [{ variant_id: product.prefixed_id }])

      expect(result[:error]).to include('is a product')
      expect(result[:variants].map { |v| v[:id] }).to match_array(product.variants.map(&:prefixed_id))
    end
  end

  describe 'refusals' do
    it 'needs someone to order for' do
      expect(tool.call(items: [{ variant_id: variant.prefixed_id }])[:error]).to include('customer_id or an email')
    end

    it 'needs at least one item' do
      expect(tool.call(email: 'buyer@example.com', items: [])[:error]).to include('at least one item')
    end

    it 'needs a variant on every line' do
      expect(tool.call(email: 'buyer@example.com', items: [{ quantity: 2 }])[:error]).to include('needs a variant_id')
    end

    it 'refuses an unknown customer' do
      expect(tool.call(customer_id: 'cust_nope', items: [{ variant_id: variant.prefixed_id }])[:error]).
        to include('No customer found')
    end

    # Another store's variant is not orderable here, so it is not found rather
    # than quietly ordered.
    it 'cannot order a variant belonging to another store' do
      theirs = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}"), status: 'active')

      result = tool.call(email: 'buyer@example.com', items: [{ variant_id: theirs.variants.first.prefixed_id }])

      expect(result[:error]).to include('No variant found')
      expect(store.orders.where(email: 'buyer@example.com')).to be_empty
    end

    it 'is withheld from a caller who may only read orders' do
      read_only = create(:api_key, :secret, store: store, scopes: ['read_orders'])

      expect(tool(Spree::AgentTools::Context.new(store: store, api_key: read_only, request_headers: agent_headers_for_key(read_only)))).to be_nil
    end

    # The service's own refusal, in its words — a draft product cannot be sold,
    # and the merchant needs to know which rule stopped it.
    it 'passes on why the order could not be created' do
      draft = create(:product, store: store, status: 'draft')

      result = tool.call(email: 'buyer@example.com', items: [{ variant_id: draft.variants.first.prefixed_id }])

      expect(result[:error]).to be_present
      expect(result[:ok]).to be_nil
    end
  end
end
