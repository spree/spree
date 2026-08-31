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

    # An owned list prices the assortment and nothing else, so it follows it
    # — those placeholder rows are what the price spreadsheet edits.
    it 'gives an owned price list rows for the products it adds' do
      list = create(:price_list, store: store)
      catalog.update!(price_list: list)
      product = create(:product, store: store, price: 100)

      expect { catalog.add_products([product.id]) }.to change { list.prices.reload.count }.from(0)
      expect(list.variants).to include(product.default_variant)
    end

    it 'drops those rows again when the product leaves the assortment' do
      list = create(:price_list, store: store)
      catalog.update!(price_list: list)
      kept = create(:product, store: store, price: 100)
      dropped = create(:product, store: store, price: 50)
      catalog.add_products([kept.id, dropped.id])

      expect { catalog.remove_products([dropped.id]) }.to change { list.prices.reload.count }

      expect(list.variants.reload).to include(kept.default_variant)
      expect(list.variants).not_to include(dropped.default_variant)
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

    expect(catalog.reload.price_list).to be_nil
  end

  # The FK lives on the list: a list is standalone or owned by exactly one
  # catalog (docs/plans/6.0-catalog-agreement-rework.md).
  describe 'price list ownership' do
    let(:price_list) { create(:price_list, :active, store: store) }

    it 'claims the list through its foreign key' do
      catalog = create(:catalog, store: store, price_list: price_list)

      expect(price_list.reload.catalog).to eq(catalog)
      expect(catalog.price_list).to eq(price_list)
    end

    it 'attaches and detaches through the association writer' do
      catalog = create(:catalog, store: store)

      catalog.update!(price_list: price_list)
      expect(price_list.reload.catalog).to eq(catalog)

      catalog.update!(price_list: nil)
      expect(price_list.reload.catalog).to be_nil
    end

    # Taking a list another catalog owns would silently un-price that
    # catalog, so moving one is detach-then-attach: two deliberate acts.
    it 'refuses a list another catalog already owns' do
      owner = create(:catalog, store: store, price_list: price_list)
      other = create(:catalog, store: store)

      expect(other.update(price_list: price_list)).to be false
      expect(other.errors[:price_list]).to be_present
      expect(price_list.reload.catalog).to eq(owner)
    end

    it 'accepts the list once its previous owner lets go' do
      owner = create(:catalog, store: store, price_list: price_list)
      other = create(:catalog, store: store)

      owner.update!(price_list: nil)

      expect(other.update(price_list: price_list)).to be true
      expect(price_list.reload.catalog).to eq(other)
    end

    # Validation re-reads the stored owner, so a list taken between the
    # caller loading it and saving is refused rather than stolen.
    it 'refuses a list claimed concurrently before this save ran' do
      other = create(:catalog, store: store)
      rival = create(:catalog, store: store)

      other.price_list = price_list
      Spree::PriceList.where(id: price_list.id).update_all(catalog_id: rival.id)

      expect(other.save).to be false
      expect(other.errors[:price_list]).to be_present
      expect(price_list.reload.catalog_id).to eq(rival.id)
    end

    # The claim itself is a conditional UPDATE, so even a list taken after
    # validation passed is never stolen — it raises instead.
    it 'raises rather than stealing a list claimed between validation and write' do
      other = create(:catalog, store: store)
      rival = create(:catalog, store: store)
      other.price_list = price_list

      allow(other).to receive(:price_list_not_owned_elsewhere) do
        Spree::PriceList.where(id: price_list.id).update_all(catalog_id: rival.id)
      end

      # The write rolls back with the transaction, so what matters is that
      # this catalog never ends up owning the list.
      expect { other.save }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(price_list.reload.catalog_id).not_to eq(other.id)
    end

    # Releasing the list would let it match by its own rules, and an owned
    # list has none — so it would price every shopper. It goes with the
    # catalog instead, soft-deleted so it stays recoverable.
    it 'takes the list with it when the catalog is destroyed' do
      catalog = create(:catalog, store: store, price_list: price_list)

      catalog.destroy!

      expect(Spree::PriceList.where(id: price_list.id)).to be_empty
      expect(Spree::PriceList.with_deleted.find(price_list.id)).to be_present
    end

    it 'does not leave the destroyed catalog list pricing the store' do
      price_list.update!(status: 'active')
      catalog = create(:catalog, store: store, price_list: price_list)
      Spree::Current.store = store
      expect(Spree::Current.price_lists.map(&:id)).not_to include(price_list.id)

      catalog.destroy!

      expect(Spree::Current.price_lists.map(&:id)).not_to include(price_list.id)
    end

    # The binding is written with update_all, which never touches the
    # instance the caller holds. Left unsynced, that copy still reads
    # catalog_id as nil and detaching from the list side looks like a no-op.
    it 'leaves the attached list agreeing with its row' do
      catalog = create(:catalog, store: store, price_list: price_list)

      expect(price_list.catalog_id).to eq(catalog.id)
      expect(price_list.changed).to be_empty

      price_list.update!(catalog: nil)

      expect(Spree::PriceList.where(id: price_list.id).pick(:catalog_id)).to be_nil
    end

    # The list is saved inside the catalog's own save, so its problems have
    # to surface as catalog errors — a bare `false` tells the merchant
    # nothing about what went wrong.
    it 'reports why an invalid new list was rejected' do
      catalog = create(:catalog, store: store)
      catalog.price_list = Spree::PriceList.new(store: store) # no name

      expect(catalog.save).to be false
      expect(catalog.errors[:price_list]).to be_present
    end

    # The binding is written straight to the row, which skips the `touch`
    # on the child's belongs_to — so the largest change to a catalog's
    # pricing would otherwise leave its cache key untouched.
    it 'bumps the catalog timestamp when its pricing changes' do
      catalog = create(:catalog, store: store)

      expect { catalog.update!(price_list: price_list) }.to change { catalog.reload.updated_at }
    end

    it 'refuses a list belonging to another store' do
      catalog = create(:catalog, store: store)
      foreign = create(:price_list, store: create(:store))

      catalog.price_list = foreign

      expect(catalog).not_to be_valid
      expect(catalog.errors[:price_list]).to be_present
    end

    # The binding is a write on the LIST, so assigning it on a persisted
    # catalog would hit the database before validation. A rejected save that
    # had already detached would release a rule-less list to the whole store
    # — the leak this design closes, arriving through the failure path.
    describe 'a rejected save' do
      it 'attaches nothing' do
        catalog = create(:catalog, store: store)

        catalog.assign_attributes(price_list: price_list, name: '')

        expect(catalog.save).to be false
        expect(price_list.reload.catalog_id).to be_nil
      end

      it 'detaches nothing' do
        catalog = create(:catalog, store: store, price_list: price_list)

        catalog.assign_attributes(price_list: nil, name: '')

        expect(catalog.save).to be false
        expect(price_list.reload.catalog_id).to eq(catalog.id)
      end

      it 'reads back the binding the caller asked for, so a form round-trips' do
        catalog = create(:catalog, store: store)

        catalog.assign_attributes(price_list: price_list, name: '')
        catalog.save

        expect(catalog.price_list).to eq(price_list)
      end
    end

    # An unsaved list has no id to bind, so it is saved through its own
    # lifecycle rather than silently dropped.
    describe 'an unsaved price list' do
      it 'is persisted and bound when the catalog is new' do
        catalog = build(:catalog, store: store)
        catalog.price_list = build(:price_list, store: store, name: 'Fresh')

        catalog.save!

        expect(catalog.price_list.reload).to be_persisted
        expect(catalog.price_list.catalog_id).to eq(catalog.id)
      end

      it 'is persisted and bound on a catalog that already exists' do
        catalog = create(:catalog, store: store)
        catalog.price_list = build(:price_list, store: store, name: 'Fresh')

        expect { catalog.save! }.to change { store.price_lists.count }.by(1)
        expect(catalog.price_list.reload.catalog_id).to eq(catalog.id)
      end
    end

    # Releasing is a compare-and-swap: a list another request already re-homed
    # must not be sent back to standalone matching, where a rule-less list
    # prices the whole store.
    it 'does not release a list that another catalog has already claimed' do
      catalog = create(:catalog, store: store, price_list: price_list)
      other = create(:catalog, store: store)

      # Stand in for a concurrent request that legitimately took the list
      # over after this record loaded it.
      Spree::PriceList.where(id: price_list.id).update_all(catalog_id: other.id)

      # `catalog` still believes it owns the list; detaching must be a no-op.
      catalog.association(:price_list).reset
      catalog.update!(price_list: nil)

      expect(price_list.reload.catalog_id).to eq(other.id)
    end

    # Rejecting through the catalog's own validation rather than raising
    # RecordNotSaved out of the child's same-store check.
    it 'refuses a foreign-store list as a validation error' do
      catalog = create(:catalog, store: store)
      foreign = create(:price_list, store: create(:store))

      catalog.price_list = foreign

      expect(catalog).not_to be_valid
      expect(catalog.errors[:price_list]).to be_present
    end
  end
end
