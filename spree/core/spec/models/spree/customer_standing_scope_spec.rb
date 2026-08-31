require 'spec_helper'

RSpec.describe 'Spree.customer_class.with_standing_for_company' do
  let(:store) { @default_store }
  let!(:parent) { create(:company, store: store, name: 'Acme Corp') }
  let!(:child) { create(:company, store: store, name: 'EMEA Division', parent: parent, kind: 'division') }

  let!(:group_buyer) { create(:user) }
  let!(:division_buyer) { create(:user) }
  let!(:outsider) { create(:user) }

  before do
    Spree::Current.store = store
    create(:company_membership, company: parent, customer: group_buyer)
    create(:company_membership, company: child, customer: division_buyer)
  end

  after { Spree::Current.reset }

  subject(:matches) { Spree.customer_class.with_standing_for_company(child) }

  # Standing covers a node and everything below it, so a member of the parent
  # may buy for the child. Filtering on the membership row alone would hide
  # the group-level buyer.
  it 'includes members of the node and of its ancestors' do
    expect(matches).to include(division_buyer, group_buyer)
    expect(matches).not_to include(outsider)
  end

  it 'excludes a subsidiary-only member when asked about the parent' do
    parent_matches = Spree.customer_class.with_standing_for_company(parent)

    expect(parent_matches).to include(group_buyer)
    expect(parent_matches).not_to include(division_buyer)
  end

  it 'accepts a prefixed id, as a Ransack scope receives it' do
    expect(Spree.customer_class.with_standing_for_company(child.prefixed_id)).to include(group_buyer)
  end

  # The dashboard's resource filter is multi-select, so the scope arrives with
  # a list rather than a single id.
  it 'accepts a list of ids and matches standing over any of them' do
    other_root = create(:company, store: store, name: 'Globex')
    globex_buyer = create(:user)
    create(:company_membership, company: other_root, customer: globex_buyer)

    matches = Spree.customer_class.with_standing_for_company([child.prefixed_id, other_root.prefixed_id])

    expect(matches).to include(division_buyer, group_buyer, globex_buyer)
    expect(matches).not_to include(outsider)
  end

  it 'returns nothing for a blank or unknown company' do
    expect(Spree.customer_class.with_standing_for_company(nil)).to be_empty
    expect(Spree.customer_class.with_standing_for_company('comp_nonexistent')).to be_empty
  end

  # The value arrives off a query string, so reading it through the global
  # constant would let one tenant filter by another's node.
  it 'refuses a company id belonging to another store' do
    other = create(:company, store: create(:store), name: 'Other Tenant')
    create(:company_membership, company: other, customer: outsider)

    expect(Spree.customer_class.with_standing_for_company(other.prefixed_id)).to be_empty
  end

  it 'returns each customer once even with several qualifying memberships' do
    create(:company_membership, company: child, customer: group_buyer)

    expect(matches.to_a.count(group_buyer)).to eq(1)
  end
end
