require 'spec_helper'

# The generic writes exist for the settings screens — the resources the Admin
# API saves directly. Everything else is written by its own workflow tool, and
# these have to say so rather than quietly doing it a second way.
RSpec.describe 'agent generic record writes' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }

  def tool(name)
    Spree.admin_agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'update_resource' do
    let(:market) { store.markets.first || create(:market, store: store) }

    it 'persists a change through the model\'s own validations' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'name' => 'Northern Europe' })

      expect(result[:error]).to be_nil
      expect(market.reload.name).to eq('Northern Europe')
    end

    it 'hands back the model\'s own message when it refuses' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'name' => '' })

      expect(result[:error]).to be_present
      expect(market.reload.name).not_to eq('')
    end

    # A resource with a workflow has exactly one way to be written, and the
    # refusal names it so the model retries with the right tool instead of
    # giving up.
    # The old refusal rule is gone. It existed because the generic writes
    # assigned attributes and saved, which would have been a second way to
    # write the same record; dispatched, this IS the controller's way, and
    # the controller runs whatever workflow it declares.
    it 'writes a resource whose controller declares a workflow' do
      product = create(:product, store: store)

      result = tool('update_resource').call(resource: 'products', id: product.prefixed_id,
                                            attributes: { 'name' => 'Renamed' })

      expect(result[:error]).to be_nil
      expect(product.reload.name).to eq('Renamed')
    end

    it 'writes a resource whose controller calls a service' do
      order = create(:order, store: store)

      result = tool('update_resource').call(resource: 'orders', id: order.prefixed_id,
                                            attributes: { 'email' => 'new@example.com' })

      expect(result[:error]).to be_nil
      expect(order.reload.email).to eq('new@example.com')
    end

    # A `/` in the id would address a nested route under the record, so the
    # approval card would describe one write and the operation perform
    # another. The path backstop cannot tell that from a real nested route,
    # so the tool refuses first.
    it 'refuses an id that is not a single path segment' do
      result = tool('update_resource').call(resource: 'markets', id: "#{market.prefixed_id}/x",
                                            attributes: { 'name' => 'Northern Europe' })

      expect(result[:error]).to include('not a record id')
      expect(market.reload.name).not_to eq('Northern Europe')
    end

    # Silently dropping an attribute leaves the model believing it set
    # something it did not; naming the real ones lets it correct itself.
    it 'names the accepted attributes when given one it does not know' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'colour' => 'blue' })

      expect(result[:error]).to include('colour')
      expect(result[:accepted_attributes]).to include('currency')
    end

    it 'does not reach another store\'s record' do
      other = create(:market, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      result = tool('update_resource').call(resource: 'markets', id: other.prefixed_id,
                                            attributes: { 'name' => 'Taken Over' })

      expect(result[:error]).to be_present
      expect(other.reload.name).not_to eq('Taken Over')
    end

    it 'refuses an unknown resource' do
      result = tool('update_resource').call(resource: 'unicorns', id: 'x', attributes: {})

      expect(result[:error]).to include('unicorns')
    end
  end

  describe 'create_resource' do
    # Built through the store's own association, so the record carries its
    # tenancy from where it was built rather than from an attribute the caller
    # could have named.
    it 'creates the record in the caller\'s store' do
      name = "Northern #{SecureRandom.hex(3)}"

      result = tool('create_resource').call(
        resource: 'markets',
        attributes: { 'name' => name, 'currency' => 'EUR', 'default_locale' => 'en', 'country_codes' => ['DE'] }
      )

      expect(result[:error]).to be_nil
      expect(Spree::Market.for_store(store).where(name: name)).to exist
    end

    it 'creates a resource whose controller declares a workflow' do
      result = tool('create_resource').call(resource: 'products',
                                            attributes: { 'name' => "Dispatched #{SecureRandom.hex(3)}" })

      expect(result[:error]).to be_nil
      expect(result[:record][:id]).to be_present
    end
  end

  # The write tools tell the caller to call describe_resource for the
  # attributes a resource accepts, so it has to answer that question.
  describe 'describe_resource and the write tools agree' do
    it 'lists the attributes a generic write accepts' do
      described = Spree.admin_agent_tools.available_for(context).
                  find { |candidate| candidate.tool_name == 'describe_resource' }.
                  call(resource: 'markets')[:resources].first

      expect(described[:writable_attributes]).to include('name', 'currency')
    end

    it 'names the create and update tools separately' do
      described = Spree.admin_agent_tools.available_for(context).
                  find { |candidate| candidate.tool_name == 'describe_resource' }.
                  call(resource: 'products')[:resources].first

      expect(described[:created_by_tool]).to eq('products_create')
      expect(described[:updated_by_tool]).to eq('products_update')
      # Reported now where it used to be withheld: the generic writes reach
      # the controller, so a resource with a workflow is writable through
      # them too and the model needs its attribute list either way.
      expect(described[:writable_attributes]).to include('name')
    end
  end

  # A create body can carry a parameter the controller translates rather than
  # assigns — a delivery profile's `kind` picks the STI subclass and is not a
  # column. The old generic write handed it to `assign_attributes` and had to
  # catch the raise; dispatched, the controller decides what to do with it,
  # so the whole class of problem belongs to the endpoint.
  describe 'an attribute the controller translates rather than assigns' do
    let(:profile) { store.delivery_profiles.first || create(:delivery_profile, store: store) }

    it 'leaves it to the endpoint rather than raising' do
      result = tool('update_resource').call(resource: 'delivery_profiles', id: profile.prefixed_id,
                                            attributes: { 'kind' => 'shipping' })

      expect(result[:error]).to be_nil
    end

    it 'applies the attributes alongside it' do
      result = tool('update_resource').call(resource: 'delivery_profiles', id: profile.prefixed_id,
                                            attributes: { 'name' => 'Renamed Profile', 'kind' => 'shipping' })

      expect(result[:error]).to be_nil
      expect(profile.reload.name).to eq('Renamed Profile')
    end
  end

  describe 'what a read-only key is offered' do
    let(:api_key) { create(:api_key, :secret, store: store, scopes: ['read_all']) }

    it 'is not offered the write tools at all' do
      names = Spree.admin_agent_tools.available_for(context).map(&:tool_name)

      expect(names).not_to include('create_resource', 'update_resource', 'delete_resource')
    end
  end
  # "Create a product named Expensive Bag with two variants (size S and M),
  # quantity 100, price 199 USD" is one call, not four. A model that creates
  # the product and then adds each variant separately pays several round
  # trips and leaves the default variant behind, since a product write
  # reconciles its variant list rather than adding to it.
  describe 'a record with its nested records' do
    let(:location) { store.stock_locations.first || create(:stock_location, store: store) }

    def variant_row(size)
      {
        'options' => [{ 'name' => 'Size', 'value' => size }],
        'prices' => [{ 'currency' => 'USD', 'amount' => '199.00' }],
        'stock_levels' => [{ 'stock_location_id' => location.prefixed_id, 'count_on_hand' => 100 }]
      }
    end

    it 'creates a product, its variants, their prices and their stock in one call' do
      result = tool('create_resource').call(
        resource: 'products',
        attributes: { 'name' => 'Expensive Bag', 'status' => 'active',
                      'variants' => [variant_row('S'), variant_row('M')] }
      )

      expect(result[:error]).to be_nil

      product = Spree::Product.for_store(store).find_by(name: 'Expensive Bag')
      # Two, not three: the variant a bare create would have left behind is
      # reconciled away by the same write.
      expect(product.variants.count).to eq(2)
      expect(product.variants.map(&:options_text)).to contain_exactly('Size: S', 'Size: M')
      expect(product.variants.map { |variant| variant.price_in('USD').amount }).to all(eq(199))
      expect(product.variants.map(&:total_on_hand)).to all(eq(100))
    end

    it 'creates an order with its line items in one call' do
      variant = create(:variant, product: create(:product, store: store))

      result = tool('create_resource').call(
        resource: 'orders',
        attributes: { 'email' => 'buyer@example.com',
                      'items' => [{ 'variant_id' => variant.prefixed_id, 'quantity' => 3 }] }
      )

      expect(result[:error]).to be_nil

      order = Spree::Order.for_store(store).find_by_prefix_id(result.dig(:record, :id))
      expect(order.line_items.sum(&:quantity)).to eq(3)
    end

    # Named rather than described: a model that is only told `variants` exists
    # sends the variants one at a time to their own endpoint. The type and
    # the requirement travel too — without them an agent learns that a field
    # is mandatory, or wants a decimal string rather than a number, only from
    # a 422.
    it 'says what fits inside a list-valued attribute' do
      described = tool('describe_resource').call(resource: 'products')[:resources].first
      fields = described[:nested_attributes]['variants']

      expect(fields.map { |field| field['name'] }).to include('options', 'prices', 'stock_levels')
      expect(described[:writable_attributes]).to include('variants')
    end

    it 'says which nested fields are required and what type they take' do
      described = tool('describe_resource').call(resource: 'purchase_orders')[:resources].first
      items = described[:nested_attributes]['items'].index_by { |field| field['name'] }

      expect(items['quantity_ordered']).to include('type' => 'integer', 'required' => true)
      # A decimal travels as a canonical string, which a model guesses wrong
      # until it is told.
      expect(items['unit_cost']).to include('type' => 'string')
    end
  end
  # A record arrives without its associations, because a full admin payload
  # is more than a model's context should hold. Naming them is how a model
  # sees the variants it just created.
  describe 'asking for a record\'s associations' do
    let(:product) do
      tool('create_resource').call(
        resource: 'products',
        attributes: { 'name' => "Expand #{SecureRandom.hex(3)}",
                      'variants' => [{ 'options' => [{ 'name' => 'Size', 'value' => 'S' }] },
                                     { 'options' => [{ 'name' => 'Size', 'value' => 'M' }] }] }
      )
    end

    def fetch(**arguments)
      tool('get_resource').call(resource: 'products', id: product.dig(:record, :id), **arguments)
    end

    it 'leaves them out by default' do
      expect(fetch[:record]).not_to have_key('variants')
    end

    it 'includes the ones it is asked for' do
      expect(fetch(expand: ['variants'])[:record]['variants'].size).to eq(2)
    end

    it 'names the real list when asked for one that does not exist' do
      result = fetch(expand: ['nonsense'])

      expect(result[:error]).to include('nonsense')
      expect(result[:expandable]).to include('variants')
    end

    it 'says which ones a resource offers' do
      described = tool('describe_resource').call(resource: 'products')[:resources].first

      expect(described[:expandable_associations]).to include('variants')
    end
  end
end
