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

    it 'appends to the existing assortment in one statement' do
      first = create(:product, store: store)
      catalog.add_products([first.id])
      later = create_list(:product, 2, store: store)

      expect { catalog.add_products(later.map(&:id)) }.
        to change { catalog.catalog_products.count }.by(2)

      expect(catalog.products.reload).to contain_exactly(first, *later)
    end

    it 'adds a batch alongside an existing row without raising on the duplicate' do
      existing = create(:product, store: store)
      fresh = create(:product, store: store)
      catalog.add_products([existing.id])

      expect(catalog.add_products([existing.id, fresh.id])).to eq(1)
      expect(catalog.products.reload).to contain_exactly(existing, fresh)
    end
  end

  describe '.for_company' do
    let(:root) { create(:company, store: store) }
    let(:division) { create(:company, store: store, kind: 'division', parent: root) }

    it 'is empty with no node' do
      expect(store.catalogs.for_company(nil)).to eq([])
    end

    it 'collects assignments up the ancestor chain, nearest node first' do
      parent_catalog = create(:catalog, store: store)
      own_catalog = create(:catalog, store: store)
      create(:catalog_assignment, catalog: parent_catalog, assignable: root)
      create(:catalog_assignment, catalog: own_catalog, assignable: division)

      expect(store.catalogs.for_company(division)).to eq([own_catalog, parent_catalog])
      # The parent's own resolution sees only its own assignment.
      expect(store.catalogs.for_company(root)).to eq([parent_catalog])
    end

    it 'ignores inactive catalogs and sibling assignments' do
      inactive = create(:catalog, store: store, active: false)
      create(:catalog_assignment, catalog: inactive, assignable: division)
      sibling = create(:company, store: store, kind: 'division', parent: root)
      create(:catalog_assignment, catalog: create(:catalog, store: store), assignable: sibling)

      expect(store.catalogs.for_company(division)).to eq([])
    end

    it 'orders several catalogs on one node by position' do
      second = create(:catalog, store: store)
      first = create(:catalog, store: store)
      first.update!(position: 1)
      second.update!(position: 2)
      create(:catalog_assignment, catalog: second, assignable: division)
      create(:catalog_assignment, catalog: first, assignable: division)

      expect(store.catalogs.for_company(division)).to eq([first, second])
    end
  end

  describe '.for_context' do
    let(:company) { create(:company, store: store) }

    it 'returns company catalogs and ignores ones that do not apply' do
      assigned = create(:catalog, store: store)
      create(:catalog, store: store)
      create(:catalog_assignment, catalog: assigned, assignable: company)

      expect(described_class.for_context(store: store, company: company)).to eq([assigned])
    end

    it 'falls back to the channel default catalog when nothing narrower applies' do
      catalog = create(:catalog, store: store)
      channel = store.default_channel
      channel.update!(default_catalog: catalog)

      expect(described_class.for_context(store: store, channel: channel)).to eq([catalog])
    end
  end

  describe 'assignments' do
    let(:catalog) { create(:catalog, store: store) }

    it 'accepts the buyer-audience assignable types' do
      expect(build(:catalog_assignment, catalog: catalog,
                                        assignable: create(:company, store: store))).to be_valid
      expect(build(:catalog_assignment, catalog: catalog,
                                        assignable: create(:customer_group, store: store))).to be_valid
    end

    # Channel and Market were assignable in the 6.0 pre-release but never
    # read (decisions.md 2026-08-28) — a channel's catalog is its
    # default_catalog, a market catalog waits for its reader.
    it 'refuses anything else, the retired channel and market types included' do
      expect(build(:catalog_assignment, catalog: catalog, assignable: store.default_channel)).not_to be_valid
      expect(build(:catalog_assignment, catalog: catalog, assignable: store.default_market)).not_to be_valid
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

  # The assignment validates same-store on write; the read must not trust it,
  # or a row that arrived past the validation would hand another tenant's
  # catalog to this buyer.
  describe 'store scoping in resolution' do
    it 'ignores an assignment pointing at another store catalog' do
      company = create(:company, store: store)
      foreign_catalog = create(:catalog, store: create(:store))
      Spree::CatalogAssignment.new(catalog: foreign_catalog, assignable: company).save(validate: false)

      expect(store.catalogs.for_company(company)).to eq([])
    end

    it 'ignores a foreign catalog assigned to a customer group' do
      group = create(:customer_group, store: store)
      foreign_catalog = create(:catalog, store: create(:store))
      Spree::CatalogAssignment.new(catalog: foreign_catalog, assignable: group).save(validate: false)

      expect(store.catalogs.for_customer_groups([group])).to eq([])
    end

    # The tenant comes from the relation the caller starts at, never from the
    # company handed in — so asking one store about another store's node
    # resolves nothing, whatever that node is assigned.
    it 'resolves against the receiving store rather than the company own store' do
      other_store = create(:store)
      company = create(:company, store: other_store)
      catalog = create(:catalog, store: other_store)
      create(:catalog_assignment, catalog: catalog, assignable: company)

      expect(other_store.catalogs.for_company(company)).to eq([catalog])
      expect(store.catalogs.for_company(company)).to eq([])
    end
  end

  describe '#import_products_from_price_list' do
    let(:product) { create(:product, store: store, price: 100) }
    let(:price_list) do
      create(:price_list, store: store).tap { |list| list.add_products([product.id]) }
    end

    it 'copies the list products into the assortment' do
      catalog = create(:catalog, store: store, price_list: price_list)

      expect(catalog.import_products_from_price_list).to eq(1)
      expect(catalog.products.reload).to contain_exactly(product)
    end

    # Deliberately never automatic — an empty assortment is a pricing-only
    # overlay, so restricting is an explicit act.
    it 'does not run on price list selection' do
      catalog = create(:catalog, store: store)

      catalog.update!(price_list: price_list)

      expect(catalog.products.reload).to be_empty
    end

    it 'answers zero without a price list' do
      expect(create(:catalog, store: store).import_products_from_price_list).to eq(0)
    end
  end

  it 'keeps the catalog when its price list is deleted' do
    price_list = create(:price_list, store: store)
    catalog = create(:catalog, store: store, price_list: price_list)

    price_list.destroy

    expect(catalog.reload.price_list_id).to be_nil
  end
end
