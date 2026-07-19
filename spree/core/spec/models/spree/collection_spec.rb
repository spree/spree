require 'spec_helper'

RSpec.describe Spree::Collection, type: :model do
  let(:store) { @default_store }

  describe 'metadata' do
    it 'defaults to an empty hash and round-trips a JSON value' do
      collection = create(:collection, metadata: { erp_id: '123' })
      expect(create(:collection).metadata).to eq({})
      expect(collection.reload.metadata).to eq({ 'erp_id' => '123' })
    end
  end

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

      it 'treats contains like is_equal_to (on sale)' do
        create(:sale_collection_rule, :contains, collection: collection)

        expect(collection.reload.products_matching_rules).to contain_exactly(on_sale)
      end

      it 'treats does_not_contain like is_not_equal_to (not on sale)' do
        create(:sale_collection_rule, :does_not_contain, collection: collection)

        expect(collection.reload.products_matching_rules).to contain_exactly(not_on_sale)
      end
    end
  end

  describe '#slug / #slug=' do
    it 'reads the permalink' do
      expect(create(:collection, name: 'Summer Sale').slug).to eq('summer-sale')
    end

    it 'writes through to the permalink' do
      collection = build(:collection)
      collection.slug = 'custom-slug'

      expect(collection.permalink).to eq('custom-slug')
    end
  end

  describe '#regenerate_products' do
    let(:collection) { create(:automatic_collection) }
    let!(:sale_product) { create(:product, tag_list: 'sale') }

    before do
      create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')
      Spree::ProductCollection.where(collection_id: collection.id).delete_all
    end

    subject(:reloaded_collection) { Spree::Collection.find(collection.id) }

    def membership_product_ids
      Spree::ProductCollection.where(collection_id: collection.id).pluck(:product_id)
    end

    it 'rebuilds the materialized membership from the rules' do
      reloaded_collection.regenerate_products

      expect(membership_product_ids).to contain_exactly(sale_product.id)
    end

    it 'clears the flag and no-ops on a second only_once call' do
      reloaded_collection.regenerate_products(only_once: true)

      expect(reloaded_collection.marked_for_regenerate_products?).to be(false)
      expect(membership_product_ids).to contain_exactly(sale_product.id)

      Spree::ProductCollection.where(collection_id: collection.id).delete_all
      reloaded_collection.regenerate_products(only_once: true)

      expect(membership_product_ids).to be_empty
    end

    it 'does nothing when not marked for regeneration' do
      reloaded_collection.marked_for_regenerate_products = false
      reloaded_collection.regenerate_products

      expect(membership_product_ids).to be_empty
    end
  end

  # The Admin API sends the full desired rule set; #rules= syncs it (build/update/destroy)
  # like Spree::OptionType#option_values=. Operate on a freshly-loaded record (as the
  # controller does via find_resource + scope_includes [:rules]) so the in-memory rule
  # set reflects current DB state.
  describe '#rules= (sync setter)' do
    let(:collection) { create(:automatic_collection) }

    subject(:reloaded_collection) { Spree::Collection.find(collection.id) }

    it 'builds new rules from attribute hashes, selecting the STI subclass by type' do
      reloaded_collection.rules = [{ type: 'Spree::CollectionRules::Tag', value: 'sale', match_policy: 'is_equal_to' }]
      reloaded_collection.save!

      rule = reloaded_collection.reload.rules.first
      expect(reloaded_collection.rules.size).to eq(1)
      expect(rule).to be_a(Spree::CollectionRules::Tag)
      expect(rule.value).to eq('sale')
      expect(rule.match_policy).to eq('is_equal_to')
    end

    it 'updates an existing rule matched by its prefixed id' do
      rule = create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')

      reloaded_collection.rules = [{ id: rule.prefixed_id, value: 'clearance', match_policy: 'contains' }]
      reloaded_collection.save!

      expect(rule.reload.value).to eq('clearance')
      expect(rule.match_policy).to eq('contains')
    end

    it 'destroys rules omitted from the payload' do
      keep = create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')
      drop = create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'new')

      reloaded_collection.rules = [{ id: keep.prefixed_id, value: 'sale', match_policy: 'is_equal_to' }]
      reloaded_collection.save!

      expect(reloaded_collection.reload.rules).to contain_exactly(keep)
      expect { drop.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises RecordNotFound for an unknown rule id' do
      expect {
        reloaded_collection.rules = [{ id: 'crule_nonexistent', value: 'x', match_policy: 'is_equal_to' }]
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'falls back to the association writer when given CollectionRule records' do
      rule = build(:tag_collection_rule, :is_equal_to, value: 'sale')

      reloaded_collection.rules = [rule]

      expect(reloaded_collection.rules).to contain_exactly(rule)
    end
  end
end
