require 'spec_helper'

# The arrangement a marketplace actually builds: a few rates targeting
# specific products and categories, a deal or two for particular sellers, and
# a global rate for everything else.
#
# Worth pinning as one spec rather than only in pieces, because it is the
# claim the defaults make — that an operator who never touches ordering gets
# the ladder they expect, purely from creating rates in the order they think
# of them.
RSpec.describe 'a typical commission setup' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:cameras) { create(:category, store: store) }
  let(:order) { create(:order, store: store, currency: 'USD') }

  let(:promoted) { create(:product, store: store, seller: seller).tap { |p| p.categories << cameras } }
  let(:camera) { create(:product, store: store, seller: seller).tap { |p| p.categories << cameras } }
  let(:other_goods) { create(:product, store: store, seller: seller) }
  let(:first_party) { create(:product, store: store) }

  before do
    Spree::Seeds::CommissionRates.call
    store.commission_rates.find_by(code: Spree::Seeds::CommissionRates::DEFAULT_CODE).
      update!(enabled: true, value: 20)

    seller_deal = create(:commission_rate, store: store, name: 'Acme deal', value: 12)
    create(:commission_seller_rule, commission_rate: seller_deal, sellers: [seller])

    category_rate = create(:commission_rate, store: store, name: 'Cameras', value: 8)
    create(:commission_category_rule, commission_rate: category_rate, categories: [cameras])

    promo = create(:commission_rate, store: store, name: 'Launch promo', value: 3)
    create(:commission_product_rule, commission_rate: promo, products: [promoted])
  end

  def rate_for(product)
    line = create(:line_item, order: order, variant: product.default_variant, price: 100)
    Spree::Commissions::ResolveRate.call(
      line_item: line, seller: product.seller, store: store, currency: 'USD'
    ).value
  end

  # Nobody dragged anything: each rate was created after the ones it should
  # beat, and lands above them.
  it 'orders itself from most specific to least, without being told to' do
    expect(store.commission_rates.ordered.pluck(:name)).
      to eq(['Launch promo', 'Cameras', 'Acme deal', 'Marketplace default'])
  end

  it 'charges the product rate on the promoted product' do
    expect(rate_for(promoted).value).to eq(3)
  end

  it 'charges the category rate on that seller other cameras' do
    expect(rate_for(camera).value).to eq(8)
  end

  it 'charges the seller deal on their goods outside that category' do
    expect(rate_for(other_goods).value).to eq(12)
  end

  it 'charges the marketplace rate on everything else' do
    expect(rate_for(first_party).value).to eq(20)
  end
end
