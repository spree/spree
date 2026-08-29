require 'spec_helper'

describe 'catalog-aware pricing' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }
  let(:company) { create(:company, store: store) }
  let(:division) { create(:company, store: store, kind: 'division', parent: company) }

  def price_list_with_price(amount)
    price_list = create(:price_list, store: store, status: 'active')
    create(:price, variant: variant, currency: 'USD', amount: amount, price_list: price_list)
    price_list
  end

  def resolve(company: nil, user: nil)
    context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store,
                                          user: user, company: company)
    Spree::Pricing::PriceResolution.call(context)
  end

  it 'prices from the catalog price list for a member of the audience' do
    catalog = create(:catalog, store: store, price_list: price_list_with_price(80))
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve(company: company).amount).to eq(80)
  end

  it 'reaches the parent assignment from a division' do
    catalog = create(:catalog, store: store, price_list: price_list_with_price(80))
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve(company: division).amount).to eq(80)
  end

  it 'prefers the nearest node when both assign priced catalogs' do
    parent_catalog = create(:catalog, store: store, price_list: price_list_with_price(90))
    own_catalog = create(:catalog, store: store, price_list: price_list_with_price(70))
    create(:catalog_assignment, catalog: parent_catalog, assignable: company)
    create(:catalog_assignment, catalog: own_catalog, assignable: division)

    expect(resolve(company: division).amount).to eq(70)
    expect(resolve(company: company).amount).to eq(90)
  end

  # A price list attached to a catalog is audience-scoped by the catalog; a
  # rule-less one must not leak to every shopper through the generic matcher.
  it 'hides a catalog price list from buyers outside the audience' do
    catalog = create(:catalog, store: store, price_list: price_list_with_price(80))
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve.amount).to eq(100)
  end

  it 'prices through a customer group catalog' do
    customer = create(:customer)
    group = create(:customer_group, store: store)
    group.customer_group_users.create!(customer: customer)
    catalog = create(:catalog, store: store, price_list: price_list_with_price(85))
    create(:catalog_assignment, catalog: catalog, assignable: group)

    expect(resolve(user: customer).amount).to eq(85)
  end

  it 'falls back to base price when the catalog has no price list' do
    catalog = create(:catalog, store: store)
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve(company: company).amount).to eq(100)
  end

  it 'prices through the channel default catalog when nothing narrower applies' do
    catalog = create(:catalog, store: store, price_list: price_list_with_price(95))
    channel = store.default_channel
    channel.update!(default_catalog: catalog)

    context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store,
                                          channel: channel)

    expect(Spree::Pricing::Resolver.new(context).resolve.amount).to eq(95)
  end

  # An inactive catalog is off: it must neither price its audience nor keep
  # claiming its list away from the generic rule matcher — a rule-less list
  # that worked before the catalog draft existed has to keep working.
  it 'releases a price list back to rule matching while its catalog is inactive' do
    price_list = price_list_with_price(80)
    catalog = create(:catalog, store: store, price_list: price_list, active: false)
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve(company: company).amount).to eq(80)
    expect(resolve.amount).to eq(80)
  end

  # Product listings build one Pricing::Context per variant. The bound
  # price-list ids and the catalogs that apply to this buyer are request
  # scoped, so later rows must not query catalogs again.
  it 'loads applicable catalogs once across many variant resolutions' do
    catalog = create(:catalog, store: store, price_list: price_list_with_price(80))
    create(:catalog_assignment, catalog: catalog, assignable: company)
    variants = create_list(:variant, 3)

    catalog_query_count = lambda do |&block|
      queries = 0
      counter = lambda do |*, payload|
        next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)

        queries += 1 if payload[:sql].include?('spree_catalogs')
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
      queries
    end

    price_variants = lambda do |records|
      records.each do |priced_variant|
        Spree::Pricing::PriceResolution.call(
          Spree::Pricing::Context.new(
            variant: priced_variant, currency: 'USD', store: store, company: company
          )
        )
      end
    end

    Spree::Current.store = store
    single = catalog_query_count.call { price_variants.call(variants.take(1)) }

    Spree::Current.reset
    Spree::Current.store = store
    batched = catalog_query_count.call { price_variants.call(variants) }

    expect(batched).to eq(single)
    expect(single).to be > 0
  end
end
