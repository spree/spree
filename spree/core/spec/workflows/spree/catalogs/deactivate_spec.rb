require 'spec_helper'

RSpec.describe Spree::Catalogs::Deactivate do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }

  it 'takes the agreement out of effect' do
    expect(described_class.call(catalog: catalog)).to be_success
    expect(catalog.reload).not_to be_active
  end

  # Nothing is torn down: activating again resumes the same agreement.
  it 'leaves what the catalog holds untouched' do
    assignment = create(:catalog_assignment, catalog: catalog,
                                             assignable: create(:company, store: store))
    product = create(:product, store: store)
    catalog.add_products([product.id])

    described_class.call(catalog: catalog)

    expect(catalog.reload.catalog_assignments).to include(assignment)
    expect(catalog.products).to include(product)
  end

  # An agreement that has to stop applying has to be able to stop, whatever
  # state it is in — unlike activating, this is never refused.
  it 'deactivates a catalog nobody is assigned to' do
    expect(described_class.call(catalog: catalog)).to be_success
    expect(catalog.reload).not_to be_active
  end
  # The list a catalog owns is reached only through that catalog, so
  # deactivating the agreement is what stops its prices — the list's own
  # status is left alone, and stays available if the catalog goes live again.
  describe 'the prices the agreement gave' do
    let(:company) { create(:company, store: store) }
    let(:product) { create(:product, store: store, price: 100) }

    before { create(:catalog_assignment, catalog: catalog, assignable: company) }

    def price_for(quantity: nil)
      context = Spree::Pricing::Context.new(
        variant: product.default_variant, currency: 'USD', store: store,
        company: company, quantity: quantity
      )
      Spree::PricingProvider::Internal.new.price_for(context).amount
    end

    it 'stops applying, without touching the list itself' do
      list = create(:price_list, :active, store: store, catalog: catalog,
                                          price_adjustment_percentage: -20)
      expect(price_for).to eq(80)

      described_class.call(catalog: catalog)

      expect(price_for).to eq(100)
      expect(list.reload.status).to eq('active')
    end

    # An owned list carries no audience of its own, so a rule on it must not
    # let it back into generic matching once the catalog is dormant — that is
    # the store-wide leak this design exists to close.
    it 'leaves a rule-bearing list unreachable rather than store-wide' do
      list = create(:price_list, :active, store: store, catalog: catalog,
                                          price_adjustment_percentage: -20)
      create(:volume_price_rule, price_list: list, min_quantity: 1)

      described_class.call(catalog: catalog)

      expect(price_for(quantity: 5)).to eq(100)
    end
  end
end
