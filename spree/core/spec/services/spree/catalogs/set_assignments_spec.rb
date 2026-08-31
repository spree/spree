require 'spec_helper'

RSpec.describe Spree::Catalogs::SetAssignments do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }
  let(:company) { create(:company, store: store) }
  let(:group) { create(:customer_group, store: store) }

  def apply(assignables)
    described_class.call(catalog: catalog, assignables: assignables)
  end

  it 'assigns each audience given' do
    apply([company, group])

    expect(catalog.catalog_assignments.reload.map(&:assignable)).to match_array([company, group])
  end

  # The set arrives whole, so an audience left out is one the merchant removed.
  it 'withdraws an audience absent from the payload' do
    apply([company, group])

    apply([company])

    expect(catalog.catalog_assignments.reload.map(&:assignable)).to eq([company])
  end

  it 'withdraws every audience for an empty payload' do
    apply([company])

    apply([])

    expect(catalog.catalog_assignments.reload).to be_empty
  end

  # Re-sending an audience that is already assigned must not duplicate it,
  # nor churn the row it already has.
  it 'leaves an audience already assigned alone' do
    apply([company])
    existing = catalog.catalog_assignments.reload.first

    apply([company, group])

    expect(catalog.catalog_assignments.reload.find_by(assignable: company).id).to eq(existing.id)
    expect(catalog.catalog_assignments.count).to eq(2)
  end

  it 'tells the two audience kinds apart even when their ids collide' do
    # A company and a group can share an id — the pair is what identifies a row.
    apply([company])

    apply([company, group])

    expect(catalog.catalog_assignments.reload.map(&:assignable_type).uniq).
      to match_array(%w[Spree::Company Spree::CustomerGroup])
  end
end
