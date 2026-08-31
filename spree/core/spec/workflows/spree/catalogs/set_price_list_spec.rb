require 'spec_helper'

# The inline price-list payload: a catalog and the list it prices through are
# written together (docs/plans/6.0-catalog-agreement-rework.md).
describe Spree::Catalogs::SetPriceList do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  def call(attributes)
    described_class.call(catalog: catalog, attributes: attributes)
  end

  it 'creates the owned list, naming it after the catalog' do
    expect(call(price_adjustment_percentage: '-15')).to be_success

    list = catalog.reload.price_list
    expect(list.name).to eq('Wholesale')
    expect(list.price_adjustment_percentage).to eq(-15)
  end

  # The catalog's own `active` flag already gates the agreement; a second
  # dormant switch inside it would only configure pricing that does nothing.
  it 'gives the new list an active status rather than draft' do
    call(price_adjustment_percentage: '-15')

    expect(catalog.reload.price_list).to be_active
  end

  it 'honours an explicit name and status' do
    call(name: 'Negotiated', status: 'draft', price_adjustment_percentage: '-5')

    list = catalog.reload.price_list
    expect(list.name).to eq('Negotiated')
    expect(list).to be_draft
  end

  it 'updates the list already owned rather than making a second one' do
    call(price_adjustment_percentage: '-15')
    original_id = catalog.reload.price_list.id

    expect { call(price_adjustment_percentage: '-20') }.not_to change { store.price_lists.count }

    expect(catalog.reload.price_list.id).to eq(original_id)
    expect(catalog.price_list.price_adjustment_percentage).to eq(-20)
  end

  # Releasing an owned list to standalone matching would let it price every
  # shopper, since an owned list has no rules of its own. The list goes with
  # the pricing it existed for — soft-deleted, so it stays recoverable.
  it 'removes the list on a blank payload rather than releasing it' do
    call(price_adjustment_percentage: '-15')
    list = catalog.reload.price_list

    expect(described_class.call(catalog: catalog, attributes: nil)).to be_success

    expect(catalog.reload.price_list).to be_nil
    expect(Spree::PriceList.where(id: list.id)).to be_empty
    expect(Spree::PriceList.with_deleted.find(list.id)).to be_present
  end

  it 'does not leave the removed list matching anyone' do
    variant = create(:variant)
    variant.prices.base_prices.with_currency('USD').update_all(amount: 20)
    call(price_adjustment_percentage: '-15')

    described_class.call(catalog: catalog, attributes: nil)

    context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store)
    expect(Spree::PricingProvider::Internal::Resolution.new(context).resolve.amount).to eq(20)
  end

  # Only an explicit nil removes the list. An empty payload says "change
  # nothing", and destroying over that would make the emptiest request the
  # most destructive one.
  it 'leaves the list alone on an empty payload' do
    call(price_adjustment_percentage: '-15')
    list = catalog.reload.price_list

    expect(described_class.call(catalog: catalog, attributes: {})).to be_success

    expect(catalog.reload.price_list).to eq(list)
    expect(Spree::PriceList.where(id: list.id)).to be_present
  end

  # The assortment usually exists before the pricing does: a merchant picks
  # products, then decides what they cost. Without this the price
  # spreadsheet opens empty on a catalog that plainly has products.
  it 'starts a new list from the assortment the catalog already holds' do
    product = create(:product, store: store, price: 100)
    catalog.add_products([product.id])

    call(name: 'Fixed')

    expect(catalog.reload.price_list.prices).to be_present
    expect(catalog.price_list.variants).to include(product.default_variant)
  end

  it 'is a no-op when detaching a catalog that owns nothing' do
    expect(described_class.call(catalog: catalog, attributes: nil)).to be_success
    expect(catalog.reload.price_list).to be_nil
  end

  # An explicit amount beats the adjustment by design, so a merchant who
  # switches to a percentage must not keep paying the old hand-entered price.
  # The dashboard sends `prices: []` on that switch.
  it 'clears hand-entered amounts when asked, so the adjustment takes over' do
    variant = create(:variant)
    variant.prices.base_prices.with_currency('USD').update_all(amount: 20)
    call(price_adjustment_percentage: nil)
    list = catalog.reload.price_list
    create(:price, variant: variant, currency: 'USD', amount: 5.00, price_list: list)

    call(price_adjustment_percentage: '-15', prices: [])

    expect(list.prices.reload.first.amount).to be_nil

    group = create(:customer_group, store: store)
    customer = create(:customer)
    group.customer_group_users.create!(customer: customer)
    create(:catalog_assignment, catalog: catalog, assignable: group)
    context = Spree::Pricing::Context.new(
      variant: variant, currency: 'USD', store: store, user: customer
    )

    expect(Spree::PricingProvider::Internal::Resolution.new(context).resolve.amount).to eq(17)
  end

  it 'fails without creating a list when the adjustment is invalid' do
    result = nil
    expect { result = call(price_adjustment_percentage: '-100') }.
      not_to change { store.price_lists.count }

    expect(result).not_to be_success
    expect(catalog.reload.price_list).to be_nil
  end
  # The inline payload is the catalog's voice, and a catalog states the terms
  # of the purchase, not who it is for. So it speaks only for the contextual
  # rules; the audience rules on the list belong to the standalone editor and
  # must survive an edit made here.
  describe 'rule reconciliation' do
    let(:catalog) { create(:catalog, store: store) }
    let!(:price_list) { create(:price_list, :active, store: store, catalog: catalog) }
    let!(:market_rule) { create(:market_price_rule, price_list: price_list) }

    it 'keeps the audience rules the payload never mentions' do
      described_class.call(
        catalog: catalog,
        attributes: { rules: [{ 'type' => 'volume_rule', 'preferences' => { 'min_quantity' => 10 } }] }
      )

      types = price_list.reload.price_rules.map { |rule| rule.class.api_type }
      expect(types).to contain_exactly('volume_rule', 'market_rule')
      # Kept, not replaced: reconciliation matches on id, so the row survives.
      expect(price_list.price_rules.find_by(type: market_rule.type).id).to eq(market_rule.id)
    end

    # The payload names kinds, not rows. A second save that repeats the kind
    # has to update the row it already has — building another would be
    # refused, and the merchant would see a 500 on an ordinary Save.
    it 'updates the rule in place when the same kind is sent again' do
      volume_payload = ->(quantity) do
        { rules: [{ 'type' => 'volume_rule', 'preferences' => { 'min_quantity' => quantity } }] }
      end

      described_class.call(catalog: catalog, attributes: volume_payload.call(10))
      original = price_list.reload.price_rules.find_by(type: 'Spree::PriceRules::VolumeRule')

      result = described_class.call(catalog: catalog, attributes: volume_payload.call(25))

      expect(result).to be_success
      rules = price_list.reload.price_rules.select { |rule| rule.is_a?(Spree::PriceRules::VolumeRule) }
      expect(rules.size).to eq(1)
      expect(rules.first.id).to eq(original.id)
      expect(rules.first.preferred_min_quantity).to eq(25)
    end

    it 'clears the contextual rules on an empty array without touching the rest' do
      create(:volume_price_rule, price_list: price_list, min_quantity: 10)

      described_class.call(catalog: catalog, attributes: { rules: [] })

      expect(price_list.reload.price_rules.map { |rule| rule.class.api_type }).to eq(['market_rule'])
    end
  end

end
