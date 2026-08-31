require 'spec_helper'

RSpec.describe Spree::Catalog, '.for_buyer' do
  let(:store) { @default_store }
  let(:customer) { create(:user) }
  let(:company) { create(:company, store: store) }
  let!(:catalog) { create(:catalog, store: store, minimum_order_quantity: 48) }

  before do
    create(:company_membership, company: company, customer: customer)
    create(:catalog_assignment, catalog: catalog, assignable: company)
    Spree::Current.reset_catalog_memos
  end

  # Every catalog-reading surface has to answer from the same set. A caller
  # that knows only the customer must still reach their company's agreement,
  # or a storefront shows one agreement's prices under another's rules.
  it "resolves a customer's sole company without being told it" do
    expect(described_class.for_buyer(store: store, customer: customer)).to eq([catalog])
  end

  it 'honours an explicitly named company' do
    expect(described_class.for_buyer(store: store, customer: customer, company: company)).to eq([catalog])
  end

  it 'resolves nothing for a customer with no standing' do
    expect(described_class.for_buyer(store: store, customer: create(:user))).to be_empty
  end

  # Guessing would put one business's agreement on another's purchase.
  it 'refuses to guess between two memberships' do
    create(:company_membership, company: create(:company, store: store), customer: customer)

    expect(described_class.for_buyer(store: store, customer: customer)).to be_empty
  end

  # Customers are global; a membership in another store must not reach here.
  it 'ignores a membership at a company in another store' do
    other_customer = create(:user)
    other_company = create(:company, store: create(:store))
    create(:company_membership, company: other_company, customer: other_customer)

    expect(described_class.for_buyer(store: store, customer: other_customer)).to be_empty
  end

  it 'is empty without a store' do
    expect(described_class.for_buyer(store: nil, customer: customer)).to eq([])
  end
end
