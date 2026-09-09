require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CatalogProductSerializer do
  let(:store) { @default_store }

  # A product can have nothing to price — its only variant soft-deleted, say.
  # That row still has to render; one degenerate product must not take the
  # whole assortment listing down with it.
  it 'renders an empty ladder for a product with no variant to price' do
    catalog = create(:catalog, store: store)
    product = create(:product, store: store, price: 50)
    allow(product).to receive(:variants).and_return(Spree::Variant.none)
    resolver = Spree::Catalogs::ResolvePrices.new(catalog: catalog, currency: 'USD')

    hash = described_class.new(
      product,
      params: { store: store, currency: 'USD', expand: ['catalog_price'],
                catalog_price_resolver: resolver }
    ).to_h

    # Present and empty, not absent: the expansion was asked for, so a client
    # reading the key must find it answered rather than missing.
    expect(hash).to have_key('catalog_variants')
    expect(hash['catalog_variants']).to eq([])
  end

  # The row carries what the card renders and nothing more — a full product
  # payload per row is what made the assortment page slow
  # (docs/plans/6.0-volume-pricing.md).
  it 'sends only the membership fields when the price is not expanded' do
    catalog = create(:catalog, store: store)
    product = create(:product, store: store, price: 50)

    hash = described_class.new(product, params: { store: store, currency: 'USD' }).to_h

    expect(hash.keys).to match_array(%w[id name thumbnail_url])
  end
end
