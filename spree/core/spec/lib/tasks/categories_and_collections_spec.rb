require 'spec_helper'
require 'rake'

describe 'spree:migrate_taxons_to_categories_and_collections' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:migrate_taxons_to_categories_and_collections' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'categories_and_collections.rake')
  end

  before { subject.reenable }

  let!(:store) { Spree::Store.default || create(:store, default: true) }

  describe 'automatic categories -> collections' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) do
      create(:automatic_taxon, taxonomy: taxonomy, store: store, name: 'On Sale',
                               sort_order: 'price asc', rules_match_policy: 'all')
    end
    let!(:rule) { create(:tag_taxon_rule, taxon: category, value: 'sale', match_policy: 'is_equal_to') }
    let!(:product) { create(:product, stores: [store]) }
    let!(:membership) { Spree::ProductCategory.create!(category: category, product: product, position: 1) }

    it 'creates a Collection mirroring the category and deletes the category' do
      permalink = category[:permalink]

      subject.invoke

      collection = Spree::Collection.find_by(store: store, permalink: permalink)
      expect(collection).to be_present
      expect(collection).to be_automatic
      expect(collection.name).to eq('On Sale')
      expect(collection.rules_match_policy).to eq('all')
      expect(collection.sort_order).to eq('price asc')

      expect(collection.rules.map(&:type)).to eq(['Spree::CollectionRules::Tag'])
      expect(collection.rules.first).to have_attributes(value: 'sale', match_policy: 'is_equal_to')

      expect(collection.products).to contain_exactly(product)
      expect(collection.reload.products_count).to eq(1)
      expect(product.reload.collections_count).to eq(1)

      expect(Spree::Category.unscoped.exists?(category.id)).to be(false)
    end
  end

  describe 'manual categories' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) { create(:taxon, taxonomy: taxonomy, store: store) }

    it 'keeps them as store-owned categories, severs taxonomy_id, creates no collection' do
      root = taxonomy.root

      subject.invoke

      expect(Spree::Category.unscoped.exists?(category.id)).to be(true)
      expect(category.reload.taxonomy_id).to be_nil
      # the root has a child, so it stays — as a top-level store-owned category
      expect(Spree::Category.unscoped.exists?(root.id)).to be(true)
      expect(root.reload.taxonomy_id).to be_nil
      expect(Spree::Collection.where(store: store)).to be_empty
    end
  end

  describe 'taxonomy roots left childless' do
    let!(:taxonomy) { create(:taxonomy, store: store) }

    it 'drops a taxonomy root with no children' do
      root = taxonomy.root

      subject.invoke

      expect(Spree::Category.unscoped.exists?(root.id)).to be(false)
    end
  end

  describe 'backfilling renamed class-name strings' do
    let!(:metafield) do
      create(:metafield).tap { |m| m.update_column(:resource_type, 'Spree::Taxon') }
    end
    let!(:promotion_rule) do
      create(:promotion_rule_taxon).tap { |r| r.update_column(:type, 'Spree::Promotion::Rules::Taxon') }
    end

    it 'rewrites Spree::Taxon* strings to Spree::Category*' do
      subject.invoke

      expect(metafield.reload.resource_type).to eq('Spree::Category')
      expect(Spree::PromotionRule.where(id: promotion_rule.id).pick(:type)).to eq('Spree::Promotion::Rules::Category')
    end
  end

  describe 'idempotency' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) { create(:automatic_taxon, taxonomy: taxonomy, store: store) }
    let!(:rule) { create(:tag_taxon_rule, taxon: category, value: 'sale', match_policy: 'is_equal_to') }

    it 'is safe to run twice without duplicating collections' do
      subject.invoke
      subject.reenable

      expect { subject.invoke }.not_to raise_error
      expect(Spree::Collection.where(store: store).count).to eq(1)
    end
  end
end
