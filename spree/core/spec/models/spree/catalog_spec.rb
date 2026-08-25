require 'spec_helper'

describe Spree::Catalog, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }

  it 'requires a name and binds to a store' do
    expect(build(:catalog, store: store, name: nil)).not_to be_valid
    expect(create(:catalog, store: store).store).to eq(store)
  end

  it 'refuses a price list from another store' do
    foreign_list = create(:price_list, store: create(:store))

    expect(build(:catalog, store: store, price_list: foreign_list)).not_to be_valid
  end

  describe '#add_products' do
    let(:catalog) { create(:catalog, store: store) }

    it 'adds store products once, skipping duplicates and foreign rows' do
      product = create(:product, store: store)
      foreign = create(:product, store: create(:store))
      catalog.add_products([product.id, foreign.id])

      expect(catalog.add_products([product.id])).to eq(0)
      expect(catalog.products.reload).to contain_exactly(product)
    end
  end

  describe '.effective_for_company' do
    let(:root) { create(:company, store: store) }
    let(:division) { create(:company, store: store, kind: 'division', parent: root) }

    it 'is empty with no node' do
      expect(described_class.effective_for_company(nil)).to eq([])
    end

    it 'collects assignments up the ancestor chain, nearest node first' do
      parent_catalog = create(:catalog, store: store)
      own_catalog = create(:catalog, store: store)
      create(:catalog_assignment, catalog: parent_catalog, assignable: root)
      create(:catalog_assignment, catalog: own_catalog, assignable: division)

      expect(described_class.effective_for_company(division)).to eq([own_catalog, parent_catalog])
      # The parent's own resolution sees only its own assignment.
      expect(described_class.effective_for_company(root)).to eq([parent_catalog])
    end

    it 'ignores inactive catalogs and sibling assignments' do
      inactive = create(:catalog, store: store, active: false)
      create(:catalog_assignment, catalog: inactive, assignable: division)
      sibling = create(:company, store: store, kind: 'division', parent: root)
      create(:catalog_assignment, catalog: create(:catalog, store: store), assignable: sibling)

      expect(described_class.effective_for_company(division)).to eq([])
    end

    it 'orders several catalogs on one node by position' do
      second = create(:catalog, store: store)
      first = create(:catalog, store: store)
      first.update!(position: 1)
      second.update!(position: 2)
      create(:catalog_assignment, catalog: second, assignable: division)
      create(:catalog_assignment, catalog: first, assignable: division)

      expect(described_class.effective_for_company(division)).to eq([first, second])
    end
  end

  describe 'assignments' do
    let(:catalog) { create(:catalog, store: store) }

    it 'accepts the four assignable types' do
      expect(build(:catalog_assignment, catalog: catalog,
                                        assignable: create(:company, store: store))).to be_valid
      expect(build(:catalog_assignment, catalog: catalog,
                                        assignable: create(:customer_group, store: store))).to be_valid
      expect(build(:catalog_assignment, catalog: catalog, assignable: store.default_market)).to be_valid
      expect(build(:catalog_assignment, catalog: catalog, assignable: store.default_channel)).to be_valid
    end

    it 'refuses anything else' do
      expect(build(:catalog_assignment, catalog: catalog, assignable: create(:product, store: store))).not_to be_valid
    end

    it 'refuses a cross-store assignment' do
      expect(build(:catalog_assignment, catalog: catalog,
                                        assignable: create(:company, store: create(:store)))).not_to be_valid
    end

    it 'is unique per catalog and assignable' do
      company = create(:company, store: store)
      create(:catalog_assignment, catalog: catalog, assignable: company)

      expect(build(:catalog_assignment, catalog: catalog, assignable: company)).not_to be_valid
    end
  end

  it 'keeps the catalog when its price list is deleted' do
    price_list = create(:price_list, store: store)
    catalog = create(:catalog, store: store, price_list: price_list)

    price_list.destroy

    expect(catalog.reload.price_list_id).to be_nil
  end
end
