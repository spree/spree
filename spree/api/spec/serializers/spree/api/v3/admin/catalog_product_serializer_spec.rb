require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CatalogProductSerializer do
  let(:store) { @default_store }

  # A product can have nothing to price — its only variant soft-deleted, say.
  # That row still has to render; one degenerate product must not take the
  # whole assortment listing down with it.
  it 'renders no catalog price for a product with no variant' do
    catalog = create(:catalog, store: store)
    product = create(:product, store: store, price: 50)
    allow(product).to receive(:featured_variant).and_return(nil)
    resolver = Spree::Catalogs::ResolvePrices.new(catalog: catalog, currency: 'USD')

    hash = described_class.new(
      product,
      params: { store: store, currency: 'USD', expand: ['catalog_price'],
                catalog_price_resolver: resolver }
    ).to_h

    expect(hash[:catalog_price]).to be_nil
  end
end
