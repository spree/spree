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
end
