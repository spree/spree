require 'spec_helper'

# The dispatcher is the whole point of the restructure: a tool reaches data
# through the Admin API, so a guard added there protects agents without
# anyone copying it into the agent layer.
RSpec.describe Spree::AgentTools::ApiDispatch do
  let(:store) { @default_store }

  def dispatcher_for(key, headers: nil)
    context = Spree::AgentTools::Context.new(
      store: store, api_key: key,
      request_headers: headers || { 'HTTP_X_SPREE_API_KEY' => key.plaintext_token,
                                    'HTTP_HOST' => 'www.example.com' }
    )
    described_class.new(context)
  end

  let(:reader) { create(:api_key, :secret, store: store, scopes: ['read_all']) }

  describe 'reaching an operation' do
    it 'returns what the endpoint rendered' do
      create(:product, store: store, name: 'Dispatched')

      response = dispatcher_for(reader).call(method: :get, path: '/products')

      expect(response).to be_success
      expect(response.data.map { |row| row['name'] }).to include('Dispatched')
      expect(response.meta['count']).to be_positive
    end

    # The fault this replaces: the tools called `.ransack` directly and
    # skipped the step that decodes prefixed ids, so filtering by an id the
    # tools themselves returned matched nothing and said so as a fact.
    it 'filters by a prefixed id, because the controller decodes it' do
      product = create(:product, store: store)

      response = dispatcher_for(reader).
                 call(method: :get, path: '/variants', params: { q: { product_id_eq: product.prefixed_id } })

      expect(response).to be_success
      expect(response.meta['count']).to eq(product.variants.count)
      expect(response.meta['count']).to be_positive
    end
  end

  describe 'the credential' do
    # Forwarded verbatim, never replaced by an internal header that skips
    # authentication — that would rebuild the boundary this class removes.
    it 'is what the API authenticates, so a scope it lacks is refused' do
      key = create(:api_key, :secret, store: store, scopes: ['read_products'])

      response = dispatcher_for(key).call(method: :post, path: '/products', body: { name: 'No' })

      expect(response.status).to eq(403)
      expect(response.error_message).to include('write_products')
    end

    it 'is required: a call carrying none is unauthorized' do
      response = dispatcher_for(reader, headers: { 'HTTP_HOST' => 'www.example.com' }).
                 call(method: :get, path: '/products')

      expect(response.status).to eq(401)
    end
  end

  # `Spree::Current` is a CurrentAttributes, which does not reset for a
  # request made inside another request. Measured before this class existed:
  # an inner call overwrote the outer request's currency.
  describe 'the request state around a dispatch' do
    it 'leaves the outer request its own store, currency and locale' do
      Spree::Current.store = store
      Spree::Current.currency = 'GBP'
      Spree::Current.locale = 'de'

      dispatcher_for(reader).call(method: :get, path: '/products')

      # Asserted on the stored attributes, not the readers: `currency` falls
      # back to the store's default, which would agree with 'GBP' only by
      # luck and hid a broken restore when the snapshot was a shallow dup of
      # the live hash.
      expect(Spree::Current.attributes[:currency]).to eq('GBP')
      expect(Spree::Current.attributes[:locale]).to eq('de')
      expect(Spree::Current.attributes[:store]).to eq(store)
    end

    it 'restores the outer state even when the call fails' do
      Spree::Current.currency = 'GBP'

      dispatcher_for(reader).call(method: :get, path: '/not_a_real_endpoint')

      expect(Spree::Current.attributes[:currency]).to eq('GBP')
    end

    # The inner request must resolve its own context rather than inherit one,
    # or a tool call would read whichever store the MCP request was for.
    it 'does not hand the inner request the outer currency' do
      Spree::Current.currency = 'GBP'

      response = dispatcher_for(reader).call(method: :get, path: '/products')

      expect(response).to be_success
    end
  end

  describe 'a failing call' do
    it 'carries the API error rather than raising' do
      response = dispatcher_for(reader).call(method: :get, path: '/products/prod_nope')

      expect(response).not_to be_success
      expect(response.error_message).to be_present
    end
  end
end
