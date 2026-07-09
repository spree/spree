require 'spec_helper'

RSpec.describe Spree::Collection, type: :model do
  let(:store) { @default_store }

  it_behaves_like 'metadata'

  describe 'permalink generation' do
    it 'derives a url-safe permalink from the name' do
      expect(create(:collection, name: 'Summer Sale').permalink).to eq('summer-sale')
    end

    it 'keeps an explicit permalink' do
      expect(create(:collection, name: 'Summer Sale', permalink: 'custom').permalink).to eq('custom')
    end

    it 'supports non-latin characters' do
      expect(create(:collection, name: '你好').permalink).to eq('ni-hao')
    end
  end

  describe 'permalink uniqueness + slug history (FriendlyId)' do
    it 'allows the same permalink in different stores' do
      other = create(:store)
      create(:collection, name: 'Summer', store: store)

      expect(build(:collection, name: 'Summer', store: other)).to be_valid
    end

    it 'rejects a duplicate permalink within the same store (errors, does not auto-suffix)' do
      create(:collection, name: 'Summer', store: store)
      duplicate = build(:collection, name: 'Summer', store: store)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:permalink]).to be_present
    end

    it 'keeps an old permalink resolving after a rename (use: :history)' do
      collection = create(:collection, name: 'Summer', store: store)
      old_permalink = collection.permalink
      collection.update!(permalink: 'winter')

      expect(described_class.friendly.find(old_permalink)).to eq(collection)
      expect(collection.reload.permalink).to eq('winter')
    end
  end

  describe 'validations' do
    it 'rejects an unknown sort_order' do
      collection = build(:collection, sort_order: 'nonsense')

      expect(collection).not_to be_valid
      expect(collection.errors[:sort_order]).to be_present
    end

    it 'rejects an unknown rules_match_policy' do
      collection = build(:collection, rules_match_policy: 'nonsense')

      expect(collection).not_to be_valid
      expect(collection.errors[:rules_match_policy]).to be_present
    end
  end

  describe '#manual? / #manual_sort_order?' do
    it { expect(build(:collection).manual?).to be(true) }
    it { expect(build(:automatic_collection).manual?).to be(false) }
    it { expect(build(:collection, sort_order: 'manual').manual_sort_order?).to be(true) }
    it { expect(build(:collection, sort_order: 'price asc').manual_sort_order?).to be(false) }
  end

  describe 'scopes' do
    let!(:manual) { create(:collection) }
    let!(:automatic) { create(:automatic_collection) }

    it 'partitions manual and automatic collections' do
      expect(described_class.manual).to include(manual)
      expect(described_class.manual).not_to include(automatic)
      expect(described_class.automatic).to include(automatic)
      expect(described_class.automatic).not_to include(manual)
    end
  end

  describe 'description (ActionText)' do
    it 'round-trips rich text' do
      collection = create(:collection, description: '<p>Hello <strong>world</strong></p>')

      expect(collection.reload.description.to_plain_text).to eq('Hello world')
    end
  end

  describe 'automatic regeneration callback' do
    let(:collection) { create(:automatic_collection) }

    it 'regenerates products when the match policy changes' do
      expect(collection).to receive(:regenerate_products)

      collection.update!(rules_match_policy: 'any')
    end

    it 'does not regenerate a manual collection on an unrelated change' do
      manual = create(:collection)
      expect(manual).not_to receive(:regenerate_products)

      manual.update!(name: 'Renamed')
    end
  end

  describe '#products_matching_rules' do
    context 'when the collection is manual' do
      let(:collection) { create(:collection) }

      it 'returns nothing' do
        expect(collection.products_matching_rules).to be_empty
      end
    end

    context 'when the collection is automatic with no rules' do
      let(:collection) { create(:automatic_collection) }

      it 'returns nothing' do
        expect(collection.products_matching_rules).to be_empty
      end
    end

    # Stub only the regeneration effect (the 1c service that wires it) so real
    # rules can persist and be read back through the association.
    context 'when the collection has tag rules' do
      before { allow(collection).to receive(:regenerate_products) }

      let(:sale_tag) { ActsAsTaggableOn::Tag.create(name: 'sale') }
      let(:new_tag) { ActsAsTaggableOn::Tag.create(name: 'new') }
      let!(:sale_product) { create(:product, tags: [sale_tag]) }
      let!(:both_product) { create(:product, tags: [sale_tag, new_tag]) }
      let!(:new_product) { create(:product, tags: [new_tag]) }

      context 'with the "all" match policy' do
        let(:collection) { create(:automatic_collection) }

        it 'matches products carrying every tag' do
          create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')
          create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'new')

          expect(collection.reload.products_matching_rules).to contain_exactly(both_product)
        end
      end

      context 'with the "any" match policy' do
        let(:collection) { create(:automatic_collection, :any_match_policy) }

        it 'matches products carrying any tag' do
          create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')
          create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'new')

          expect(collection.reload.products_matching_rules).to contain_exactly(sale_product, both_product, new_product)
        end
      end
    end

    context 'when the collection has a sale rule' do
      before { allow(collection).to receive(:regenerate_products) }

      let(:collection) { create(:automatic_collection) }
      let!(:on_sale) { create(:product, price: 10, compare_at_price: 12) }
      let!(:not_on_sale) { create(:product, price: 10) }

      it 'matches products on sale in the store currency' do
        create(:sale_collection_rule, :is_equal_to, collection: collection)

        expect(collection.reload.products_matching_rules).to contain_exactly(on_sale)
      end
    end
  end
end
