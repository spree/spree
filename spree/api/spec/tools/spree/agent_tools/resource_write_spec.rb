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

  # An order's items, discounts and fees exist only under their order, so
  # the generic tools take the order as parent_id and fill it into the path.
  describe 'a resource nested under an order' do
    let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
    let(:line_item) { order.line_items.first }
    let(:items_key) { Spree::AgentTools::ResourceMap.all.find { |entry| entry.model_name == 'Spree::LineItem' }.key }

    it 'changes a line through its order' do
      result = tool('update_resource').call(resource: items_key, id: line_item.prefixed_id,
                                            parent_id: order.prefixed_id, attributes: { 'quantity' => 4 })

      expect(result[:error]).to be_nil
      expect(line_item.reload.quantity).to eq(4)
    end

    it 'lists the lines of one order' do
      result = tool('search_resources').call(resource: items_key, parent_id: order.prefixed_id)

      expect(result[:error]).to be_nil
      expect(result[:total]).to eq(1)
    end

    it 'asks for the order rather than calling a path with a hole in it' do
      result = tool('update_resource').call(resource: items_key, id: line_item.prefixed_id,
                                            attributes: { 'quantity' => 4 })

      expect(result[:error]).to include('parent_id')
      expect(line_item.reload.quantity).not_to eq(4)
    end

    it 'is described with the record it belongs to' do
      described = tool('describe_resource').call(resource: items_key)[:resources].first

      expect(described[:parent]).to eq('orders')
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

  # A variant is written under its product, so its attribute list lives on
  # the nested route. Without it `price` was forwarded unchecked, dropped by
  # the endpoint, and reported back as changed.
  describe 'a variant written under its product' do
    let(:product) { create(:product, store: store, price: 15) }
    let(:variant) { create(:variant, product: product, price: 15) }

    def update(attributes)
      tool('update_resource').call(resource: 'variants', id: variant.prefixed_id,
                                   parent_id: product.prefixed_id, attributes: attributes)
    end

    it 'refuses a singular price and names prices instead' do
      result = update('price' => '1599.99')

      expect(result[:error]).to include('price', 'prices')
      expect(result[:accepted_attributes]).to include('prices')
      expect(variant.reload.price_in('USD').amount).to eq(15)
    end

    it 'changes the price through prices' do
      result = update('prices' => [{ 'currency' => 'USD', 'amount' => '1599.99' }])

      expect(result[:error]).to be_nil
      expect(variant.reload.price_in('USD').amount).to eq(BigDecimal('1599.99'))
    end

    it 'lists prices among its writable attributes' do
      described = tool('describe_resource').call(resource: 'variants')[:resources].first

      expect(described[:writable_attributes]).to include('prices')
      expect(described[:writable_attributes]).not_to include('price')
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

    # The base serializer explains `expand?` in a comment with `variants` as
    # the example, which once put it on every resource's list.
    it 'does not offer an association a serializer only mentions in a comment' do
      described = tool('describe_resource').call(resource: 'promotions')[:resources].first

      expect(described[:expandable_associations]).to include('rules', 'actions')
      expect(described[:expandable_associations]).not_to include('variants')
    end
  end

  # Rows selected by a `type` — a promotion's rules and actions, a price
  # list's rules, a payment method's provider — take a short name from a
  # registry. An agent that was never shown the registry guessed Ruby class
  # names, and the write dropped every row while answering success.
  describe 'typed rows' do
    def described(resource)
      tool('describe_resource').call(resource: resource)[:resources].first
    end

    it 'lists the kinds each nested row\'s type takes, with its schema and calculators' do
      nested = described('promotions')[:nested_types]
      rules = nested['rules'].index_by { |kind| kind[:type] }
      actions = nested['actions'].index_by { |kind| kind[:type] }

      expect(rules.keys).to include('item_total', 'product', 'first_order')
      expect(rules['item_total'][:schema]['properties']).to include('amount_min')
      expect(actions.keys).to include('create_item_adjustments', 'free_shipping')
      expect(actions['create_item_adjustments'][:calculators].map { |calculator| calculator[:type] }).to include('percent_on_line_item')
      expect(actions['free_shipping']).not_to have_key(:calculators)
    end

    it 'lists the kinds for every family written as nested rows' do
      expect(described('price_lists')[:nested_types]['rules'].map { |kind| kind[:type] }).to include('volume_rule')
      expect(described('delivery_methods')[:nested_types]['rules'].map { |kind| kind[:type] }).to include('weight_rule')
    end

    it 'lists the kinds a resource\'s own type takes' do
      expect(described('payment_methods')[:types].map { |kind| kind[:type] }).to include('check')
    end

    # The whole catalogue of schemas at once is more than an index should
    # cost a model's context; the listing names the kinds and no more.
    it 'names the kinds without their schemas in the full listing' do
      promotions = tool('describe_resource').call[:resources].find { |entry| entry[:resource] == 'promotions' }

      expect(promotions[:nested_types]['rules']).to include('item_total')
      expect(promotions[:nested_types]['actions']).to include('create_item_adjustments')
    end

    it 'creates a promotion with its rules and actions in one call' do
      result = tool('create_resource').call(
        resource: 'promotions',
        attributes: {
          'name' => 'Black Friday', 'kind' => 'coupon_code', 'code' => 'BLACKFRIDAY', 'usage_limit' => 500,
          'rules' => [{ 'type' => 'item_total', 'preferences' => { 'amount_min' => '100' } }],
          'actions' => [{ 'type' => 'create_item_adjustments',
                          'calculator' => { 'type' => 'percent_on_line_item', 'preferences' => { 'percent' => '25' } } }]
        }
      )

      expect(result[:error]).to be_nil

      promotion = Spree::Promotion.for_store(store).find_by(name: 'Black Friday')
      expect(promotion.rules.map { |rule| rule.class.api_type }).to eq(['item_total'])
      expect(promotion.actions.first.calculator.class.api_type).to eq('percent_on_line_item')
    end

    # "Generate 500 codes" is `multi_codes` with a count and a prefix; the
    # batch is minted by the same write, so the merchant has codes to hand
    # out as soon as the promotion exists.
    it 'creates a multi-code promotion and generates its coupon batch' do
      product = create(:product, store: store)

      result = tool('create_resource').call(
        resource: 'promotions',
        attributes: {
          'name' => 'Black Friday codes', 'kind' => 'coupon_code',
          'multi_codes' => true, 'number_of_codes' => 5, 'code_prefix' => 'BLACKFRIDAY',
          'starts_at' => '2026-11-27T00:00:00Z', 'expires_at' => '2026-11-30T23:59:59Z',
          'rules' => [{ 'type' => 'product', 'product_ids' => [product.prefixed_id], 'preferences' => { 'match_policy' => 'any' } },
                      { 'type' => 'item_total', 'preferences' => { 'amount_min' => '100', 'operator_min' => 'gt' } }],
          'actions' => [{ 'type' => 'create_item_adjustments',
                          'calculator' => { 'type' => 'percent_on_line_item', 'preferences' => { 'percent' => '25' } } }]
        }
      )

      expect(result[:error]).to be_nil

      promotion = Spree::Promotion.for_store(store).find_by(name: 'Black Friday codes')
      expect(promotion.rules.map { |rule| rule.class.api_type }).to contain_exactly('product', 'item_total')
      expect(promotion.rules.find { |rule| rule.respond_to?(:products) }.products).to eq([product])
      expect(promotion.coupon_codes.count).to eq(5)
      expect(promotion.coupon_codes.pluck(:code)).to all(start_with('blackfriday'))
    end

    it 'refuses an unknown type with the accepted ones, and creates nothing' do
      result = tool('create_resource').call(
        resource: 'promotions',
        attributes: { 'name' => 'Guessed', 'kind' => 'automatic',
                      'rules' => [{ 'type' => 'Spree::Promotion::Rules::ItemTotal' }] }
      )

      expect(result[:error]).to include('/rules/0/type', 'item_total', 'first_order')
      expect(Spree::Promotion.for_store(store).where(name: 'Guessed')).not_to exist
    end

    it 'reads a promotion\'s rules and actions through expand' do
      promotion = create(:promotion_with_item_adjustment, store: store)
      promotion.rules.create!(type: 'Spree::Promotion::Rules::FirstOrder')

      record = tool('get_resource').call(resource: 'promotions', id: promotion.prefixed_id, expand: %w[rules actions])[:record]

      expect(record['rules'].map { |rule| rule['type'] }).to eq(['first_order'])
      expect(record['actions'].map { |action| action['type'] }).to eq(['create_item_adjustments'])
    end
  end

  # A resource that only exists under a parent has no path a tool can fill
  # in. Dispatching the template as it stood answered "Promotion not found",
  # which a model reported as a fact about the store.
  describe 'the summary of a create' do
    it 'names the parent only for a resource nested under one' do
      create = tool('create_resource')

      expect(create.summary(resource: 'products', attributes: { name: 'Mug' }, parent_id: 'or_1')).to eq('Create product Mug')
      expect(create.summary(resource: 'line_items', attributes: {}, parent_id: 'or_1')).to eq('Create line item under or_1')
    end
  end

  describe 'a top-level record with no id' do
    it 'asks for the id rather than failing' do
      result = tool('get_resource').call(resource: 'products', id: '')

      expect(result[:error]).to include('Pass the id of the product')
    end
  end

  describe 'a resource reached only under a parent' do
    it 'is not searched on its own, and says where its rows live' do
      result = tool('search_resources').call(resource: 'promotion_rules')

      expect(result[:error]).to include('belong to a promotion', 'rules attribute of promotions', 'expand: ["rules"]', 'as parent_id')
      expect(result[:available]).to include('promotions')
      expect(result[:available]).not_to include('promotion_rules')
    end

    it 'is not fetched on its own' do
      result = tool('get_resource').call(resource: 'promotion_actions', id: 'pact_x')

      expect(result[:error]).to include('belong to a promotion', 'actions attribute of promotions')
    end

    it 'is not written on its own' do
      result = tool('create_resource').call(resource: 'promotion_rules', attributes: { 'type' => 'first_order' })

      expect(result[:error]).to include('cannot be created on their own', 'promotions')
    end

    it 'names the parent even when the parent carries no attribute for it' do
      result = tool('search_resources').call(resource: 'payments')

      expect(result[:error]).to include('belong to an order', 'orders')
    end

    # A hint is only offered when the caller could follow it: a read-only key
    # is told how to read the rows, not how to write them.
    context 'with a read-only key' do
      let(:api_key) { create(:api_key, :secret, store: store, scopes: ['read_promotions']) }

      it 'suggests only the calls the caller may make' do
        result = tool('search_resources').call(resource: 'promotion_rules')

        expect(result[:error]).to include('belong to a promotion', 'expand: ["rules"]')
        expect(result[:error]).not_to include('Write them')
      end
    end
  end
end
