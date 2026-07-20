require 'spec_helper'

RSpec.describe Spree::Category, type: :model do
  let(:store) { @default_store }

  describe 'uniqueness across stores' do
    it 'allows the same top-level name/permalink in different stores' do
      other = create(:store)
      described_class.create!(name: 'Shoes', store: store)
      duplicate = described_class.new(name: 'Shoes', store: other)

      expect(duplicate).to be_valid
    end

    it 'still rejects a duplicate name within the same store' do
      described_class.create!(name: 'Shoes', store: store)
      duplicate = described_class.new(name: 'Shoes', store: store)

      expect(duplicate).not_to be_valid
    end
  end

  describe 'products_count on destroy' do
    it 'decrements ancestors when a subcategory is destroyed' do
      parent = described_class.create!(name: 'Electronics', store: store)
      child = described_class.create!(name: 'Phones', parent: parent)
      Spree::ProductCategory.create!(taxon: child, product: create(:product, store: store))
      expect(parent.reload.products_count).to eq(1)

      child.destroy

      expect(parent.reload.products_count).to eq(0)
    end

    it 'keeps the count from surviving siblings' do
      parent = described_class.create!(name: 'Electronics', store: store)
      phones = described_class.create!(name: 'Phones', parent: parent)
      laptops = described_class.create!(name: 'Laptops', parent: parent)
      Spree::ProductCategory.create!(taxon: phones, product: create(:product, store: store))
      Spree::ProductCategory.create!(taxon: laptops, product: create(:product, store: store))
      expect(parent.reload.products_count).to eq(2)

      phones.destroy

      expect(parent.reload.products_count).to eq(1)
    end

    it 'decrements every ancestor level when a mid-tree node is destroyed' do
      root = described_class.create!(name: 'Root', store: store)
      mid = described_class.create!(name: 'Mid', parent: root)
      leaf = described_class.create!(name: 'Leaf', parent: mid)
      Spree::ProductCategory.create!(taxon: leaf, product: create(:product, store: store))
      expect(root.reload.products_count).to eq(1)

      mid.destroy # removes the mid + leaf subtree

      expect(root.reload.products_count).to eq(0)
    end

    it 'keeps a product still reachable through a surviving sibling (dedup)' do
      root = described_class.create!(name: 'Root', store: store)
      a = described_class.create!(name: 'A', parent: root)
      b = described_class.create!(name: 'B', parent: root)
      product = create(:product, store: store)
      Spree::ProductCategory.create!(taxon: a, product: product)
      Spree::ProductCategory.create!(taxon: b, product: product)
      expect(root.reload.products_count).to eq(1)

      a.destroy

      expect(root.reload.products_count).to eq(1)
    end
  end

  describe 'creation without a taxonomy' do
    it 'creates a parentless, store-owned top-level category' do
      category = described_class.new(name: 'Kitchen', store: store)
      expect(category).to be_valid
      category.save!

      expect(category.taxonomy).to be_nil
      expect(category.parent).to be_nil
      expect(category.store).to eq(store)
    end

    it 'does not require a taxonomy' do
      category = described_class.new(name: 'Kitchen', store: store)
      expect(category).to be_valid
      expect(category.errors[:taxonomy]).to be_empty
    end

    it 'copies the store from its parent' do
      parent = described_class.create!(name: 'Kitchen', store: store)
      child = described_class.create!(name: 'Pots', parent: parent)

      expect(child.store).to eq(store)
      expect(child.taxonomy).to be_nil
    end
  end

  describe '#requires_taxonomy?' do
    it 'is false' do
      expect(described_class.new.requires_taxonomy?).to be(false)
    end
  end

  describe 'store auto-resolution (#set_store)' do
    it 'falls back to the current store when none is given' do
      Spree::Current.store = store
      category = described_class.create!(name: 'Kitchen')

      expect(category.store).to eq(store)
    end

    it 'prefers an explicit store over the current store' do
      other = create(:store)
      Spree::Current.store = other

      category = described_class.create!(name: 'Kitchen', store: store)

      expect(category.store).to eq(store)
    end

    it 'prefers the parent store over the current store' do
      other = create(:store)
      Spree::Current.store = other
      parent = described_class.create!(name: 'Kitchen', store: store)

      child = described_class.create!(name: 'Pots', parent: parent)

      expect(child.store).to eq(store)
    end
  end

  describe '.for_store / .for_stores' do
    it 'finds taxonomy-less categories by store_id' do
      category = described_class.create!(name: 'Kitchen', store: store)
      expect(described_class.for_store(store)).to include(category)
    end

    it 'excludes categories owned by another store' do
      other = create(:store)
      mine = described_class.create!(name: 'Mine', store: store)
      theirs = described_class.create!(name: 'Theirs', store: other)

      result = described_class.for_store(store)
      expect(result).to include(mine)
      expect(result).not_to include(theirs)
    end

    it 'finds categories across multiple stores' do
      other = create(:store)
      mine = described_class.create!(name: 'Mine', store: store)
      theirs = described_class.create!(name: 'Theirs', store: other)

      expect(described_class.for_stores([store, other])).to include(mine, theirs)
    end
  end

  describe 'products_count (descendant-inclusive)' do
    let(:electronics) { described_class.create!(name: 'Electronics', store: store) }
    let(:phones) { described_class.create!(name: 'Phones', parent: electronics) }
    let(:laptops) { described_class.create!(name: 'Laptops', parent: electronics) }

    def add(product, category)
      Spree::Categories::AddProducts.call(categories: [category], products: [product])
    end

    it 'counts a directly-assigned product on the category' do
      add(create(:product, store: store), phones)

      expect(phones.reload.products_count).to eq(1)
      expect(phones.classifications.count).to eq(1) # direct
    end

    it 'rolls subcategory products up to ancestors' do
      add(create(:product, store: store), phones)
      add(create(:product, store: store), laptops)

      expect(electronics.reload.products_count).to eq(2) # inclusive
      expect(electronics.classifications.count).to eq(0) # nothing direct
      expect(phones.reload.products_count).to eq(1)
      expect(laptops.reload.products_count).to eq(1)
    end

    it 'de-duplicates a product reachable through several nodes' do
      product = create(:product, store: store)
      add(product, phones)
      add(product, electronics) # also directly on the ancestor

      expect(electronics.reload.products_count).to eq(1) # counted once
    end

    it 'decrements ancestors when a product is removed' do
      product = create(:product, store: store)
      add(product, phones)
      expect(electronics.reload.products_count).to eq(1)

      Spree::Categories::RemoveProducts.call(categories: [phones], products: [product])

      expect(electronics.reload.products_count).to eq(0)
      expect(phones.reload.products_count).to eq(0)
    end

    it 'maintains the count on a direct Classification create/destroy' do
      product = create(:product, store: store)
      classification = Spree::ProductCategory.create!(taxon: phones, product: product)
      expect(electronics.reload.products_count).to eq(1)

      classification.destroy
      expect(electronics.reload.products_count).to eq(0)
    end

    it 'updates both ancestor chains when a subtree moves' do
      other_root = described_class.create!(name: 'Office', store: store)
      add(create(:product, store: store), phones)
      expect(electronics.reload.products_count).to eq(1)

      phones.reload.move_to_child_of(other_root.reload)

      expect(electronics.reload.products_count).to eq(0) # lost the subtree
      expect(other_root.reload.products_count).to eq(1)  # gained it
    end
  end
end
