require 'spec_helper'

describe Spree::Products::ForContext do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let!(:listed) { create(:product, store: store) }
  let!(:also_listed) { create(:product, store: store) }
  let(:customer) { create(:customer) }

  def resolve(**arguments)
    described_class.call(store: store, channel: channel, **arguments).value
  end

  it 'returns every channel listing for an anonymous buyer' do
    expect(resolve).to contain_exactly(listed, also_listed)
  end

  context 'with a company catalog' do
    let(:company) { create(:company, store: store) }
    let(:catalog) { create(:catalog, store: store) }

    before do
      create(:catalog_assignment, catalog: catalog, assignable: company)
      catalog.add_products([listed.id])
    end

    it 'narrows an explicit node to its effective catalogs' do
      expect(resolve(company: company)).to contain_exactly(listed)
    end

    it 'resolves the node from a sole membership' do
      create(:company_membership, company: company, customer: customer)

      expect(resolve(customer: customer)).to contain_exactly(listed)
    end

    it 'covers the subtree of the assignment node' do
      division = create(:company, store: store, kind: 'division', parent: company)

      expect(resolve(company: division)).to contain_exactly(listed)
    end

    it 'takes the union across effective catalogs' do
      extra = create(:catalog, store: store)
      create(:catalog_assignment, catalog: extra, assignable: company)
      extra.add_products([also_listed.id])

      expect(resolve(company: company)).to contain_exactly(listed, also_listed)
    end

    it 'refuses to narrow for a buyer with several memberships and no explicit node' do
      create(:company_membership, company: company, customer: customer)
      create(:company_membership, company: create(:company, store: store), customer: customer)

      expect(resolve(customer: customer)).to contain_exactly(listed, also_listed)
    end

    # An empty assortment means the whole channel range — a pricing-only
    # overlay. Without this, "everyone sees the public store, this company
    # just gets special prices" would be impossible to express, since giving
    # the company any catalog would hide everything uncataloged.
    it 'lifts the restriction when any effective catalog is uncurated' do
      overlay = create(:catalog, store: store)
      create(:catalog_assignment, catalog: overlay, assignable: company)

      expect(resolve(company: company)).to contain_exactly(listed, also_listed)
    end

    it 'lets a division own overlay open up a parent-restricted range' do
      division = create(:company, store: store, kind: 'division', parent: company)
      overlay = create(:catalog, store: store)
      create(:catalog_assignment, catalog: overlay, assignable: division)

      expect(resolve(company: division)).to contain_exactly(listed, also_listed)
      # The parent itself stays restricted to its curated catalog.
      expect(resolve(company: company)).to contain_exactly(listed)
    end
  end

  context 'with a customer group catalog' do
    it 'narrows to the group catalog when no company applies' do
      group = create(:customer_group, store: store)
      group.customer_group_users.create!(customer: customer)
      catalog = create(:catalog, store: store)
      create(:catalog_assignment, catalog: catalog, assignable: group)
      catalog.add_products([also_listed.id])

      expect(resolve(customer: customer)).to contain_exactly(also_listed)
    end
  end

  context 'with a channel default catalog' do
    it 'narrows anonymous browsing to it' do
      catalog = create(:catalog, store: store)
      catalog.add_products([listed.id])
      channel.update!(default_catalog: catalog)

      expect(resolve).to contain_exactly(listed)
    end
  end
end
