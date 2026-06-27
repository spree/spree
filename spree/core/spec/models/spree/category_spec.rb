require 'spec_helper'

RSpec.describe Spree::Category, type: :model do
  let(:store) { @default_store }

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
end
