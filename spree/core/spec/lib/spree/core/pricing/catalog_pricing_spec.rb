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

  def resolve(company: nil, user: nil, quantity: nil)
    context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store,
                                          user: user, company: company, quantity: quantity)
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

  # A division's own agreement is the one it negotiated, so it answers even
  # when the group-wide catalog above it happens to be cheaper. Precedence
  # between nodes is real; precedence within a node is not (see below).
  it 'keeps the nearest node even when the parent catalog is cheaper' do
    parent_catalog = create(:catalog, store: store, price_list: price_list_with_price(70))
    own_catalog = create(:catalog, store: store, price_list: price_list_with_price(90))
    create(:catalog_assignment, catalog: parent_catalog, assignable: company)
    create(:catalog_assignment, catalog: own_catalog, assignable: division)

    expect(resolve(company: division).amount).to eq(90)
  end

  # Two catalogs on one node rank equally: nothing about either assignment
  # says which agreement a company is on, so the buyer pays the better of the
  # two. Catalog position orders the admin listing and must not decide money —
  # it used to, so reordering that screen silently overcharged a company
  # (V-3635).
  context 'when one company carries two catalogs' do
    let!(:shallow) do
      catalog = create(:catalog, store: store, price_list: price_list_with_price(95), position: 1)
      create(:catalog_assignment, catalog: catalog, assignable: company)
      catalog
    end

    let!(:deep) do
      price_list = price_list_with_price(85)
      create(:price, variant: variant, currency: 'USD', amount: 50, min_quantity: 24, price_list: price_list)
      catalog = create(:catalog, store: store, price_list: price_list, position: 2)
      create(:catalog_assignment, catalog: catalog, assignable: company)
      catalog
    end

    it 'charges the best price either of them gives' do
      expect(resolve(company: company).amount).to eq(85)
      expect(resolve(company: company, quantity: 24).amount).to eq(50)
    end

    it 'answers the same whichever catalog sorts first' do
      before_swap = resolve(company: company, quantity: 24).amount

      shallow.update!(position: 2)
      deep.update!(position: 1)
      Spree::Current.reset_catalog_memos

      expect(resolve(company: company, quantity: 24).amount).to eq(before_swap)
    end

    # The cheaper catalog prices this variant and the dearer one does not, so
    # there is nothing to compare — the node still answers rather than falling
    # through to the base price.
    it 'answers from the only catalog that prices the variant' do
      deep.price_list.prices.destroy_all

      expect(resolve(company: company, quantity: 24).amount).to eq(95)
    end
  end

  it 'charges the best price across several customer group catalogs' do
    customer = create(:customer)
    dearer_group = create(:customer_group, store: store)
    cheaper_group = create(:customer_group, store: store)
    dearer_group.customer_group_users.create!(customer: customer)
    cheaper_group.customer_group_users.create!(customer: customer)
    create(:catalog_assignment,
           catalog: create(:catalog, store: store, price_list: price_list_with_price(90), position: 1),
           assignable: dearer_group)
    create(:catalog_assignment,
           catalog: create(:catalog, store: store, price_list: price_list_with_price(75), position: 2),
           assignable: cheaper_group)

    expect(resolve(user: customer).amount).to eq(75)
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

  # An inactive catalog is off, and its owned list goes dormant WITH it: the
  # old derived exclusion set read active catalogs only, so deactivating a
  # catalog dropped its typically rule-less list into generic matching and
  # priced the whole store (docs/plans/6.0-catalog-agreement-rework.md).
  # Releasing the list is an explicit detach, never a side effect.
  it 'keeps an inactive catalog price list dormant until explicitly detached' do
    price_list = price_list_with_price(80)
    catalog = create(:catalog, store: store, price_list: price_list, active: false)
    create(:catalog_assignment, catalog: catalog, assignable: company)

    expect(resolve(company: company).amount).to eq(100)
    expect(resolve.amount).to eq(100)

    price_list.update!(catalog: nil)

    expect(resolve.amount).to eq(80)
  end

  # Detaching through the catalog writes the list's FK directly, skipping
  # PriceList's own callbacks — the request-scoped matching set has to be
  # cleared anyway, or the released list stays invisible until the next
  # request.
  it 'sees a detach made through the catalog within the same request' do
    price_list = price_list_with_price(80)
    catalog = create(:catalog, store: store, price_list: price_list)

    Spree::Current.store = store
    expect(resolve.amount).to eq(100)

    catalog.update!(price_list: nil)

    expect(resolve.amount).to eq(80)
  end

  # Product listings build one Pricing::Context per variant. The catalogs
  # that apply to this buyer are request scoped, so later rows must not
  # query catalogs again.
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
