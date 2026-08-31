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

  # A bare id match would resolve a company for anything answering #id — an
  # admin user sharing an id with a customer, a value object off a request.
  it 'resolves nothing for a non-customer that merely answers to an id' do
    impostor = Struct.new(:id).new(customer.id)

    expect(described_class.for_buyer(store: store, customer: impostor)).to be_empty
    expect(Spree::Company.sole_standing_for(store: store, customer: impostor)).to be_nil
  end

  # Catalog resolution asks for the company on every entry, and a listing
  # prices every variant through that path.
  it 'resolves the buyer only once per request' do
    Spree::Current.store = store
    Spree::Current.reset_catalog_memos
    queries = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries += 1 if payload[:sql].to_s.include?('spree_companies')
    end

    5.times { described_class.for_buyer(store: store, customer: customer) }
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(queries).to eq(1)
  end

  # The request memo keys on an id, so an admin and a customer sharing one
  # would share an entry — whichever resolved first deciding for both.
  it 'keeps a non-customer out of the request memo in either order' do
    Spree::Current.store = store
    impostor = Struct.new(:id).new(customer.id)

    Spree::Current.reset_catalog_memos
    expect(Spree::Current.standing_company_for(customer)).to eq(company)
    expect(Spree::Current.standing_company_for(impostor)).to be_nil

    Spree::Current.reset_catalog_memos
    expect(Spree::Current.standing_company_for(impostor)).to be_nil
    expect(Spree::Current.standing_company_for(customer)).to eq(company)
  end

  it 'is empty without a store' do
    expect(described_class.for_buyer(store: nil, customer: customer)).to eq([])
  end
end
