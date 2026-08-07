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
      Spree::Category.create!(taxonomy: taxonomy, store: store, name: 'On Sale', automatic: true,
                              sort_order: 'price asc', rules_match_policy: 'all')
    end
    let!(:rule) { create(:tag_taxon_rule, taxon: category, value: 'sale', match_policy: 'is_equal_to') }
    let!(:product) { create(:product, store: store) }
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
    # A child of the root, so the root survives the childless-root sweep.
    let!(:category) { create(:category, taxonomy: taxonomy, store: store, parent: taxonomy.root) }

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

  describe 'ActionText descriptions on surviving categories' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) do
      create(:category, taxonomy: taxonomy, store: store, parent: taxonomy.root).tap do |c|
        c.update!(description: '<div>Kept description</div>')
        # simulate a pre-6.0 row still typed as Spree::Taxon
        ActionText::RichText.where(record_id: c.id, name: 'description').update_all(record_type: 'Spree::Taxon')
      end
    end

    it 'backfills record_type so the rich-text description survives the rename' do
      subject.invoke

      expect(category.reload.description.to_plain_text).to eq('Kept description')
    end
  end

  describe 'idempotency' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) { Spree::Category.create!(taxonomy: taxonomy, store: store, name: 'On Sale', automatic: true) }
    let!(:rule) { create(:tag_taxon_rule, taxon: category, value: 'sale', match_policy: 'is_equal_to') }

    it 'is safe to run twice without duplicating collections' do
      subject.invoke
      subject.reenable

      expect { subject.invoke }.not_to raise_error
      expect(Spree::Collection.where(store: store).count).to eq(1)
    end
  end

  # Pre-6.0 permalinks were unique per taxonomy, so one store could hold two
  # identical permalinks under different taxonomies. In 6.0 the permalink is the
  # category's full path and must be unique per store — without disambiguation the
  # backfill trips the unique index and aborts the task, leaving a half-migrated store.
  describe 'colliding permalinks' do
    # Builds +count+ taxonomies whose roots share a permalink, each keeping a child
    # so the childless-root sweep can't quietly resolve the collision for us.
    def build_colliding_roots(count, permalink: 'catalog')
      taxonomies = Array.new(count) { |i| create(:taxonomy, name: "Shop #{i}", store: store) }

      taxonomies.each_with_index do |taxonomy, index|
        create(:category, name: "Child #{index}", taxonomy: taxonomy, parent: taxonomy.root)
      end

      # Clear store_id first — that is the genuine pre-upgrade state, and it is what
      # keeps these rows out of the store-scoped index while we set up the collision.
      Spree::Category.unscoped.update_all(store_id: nil)

      taxonomies.each do |taxonomy|
        Spree::Category.unscoped.where(id: taxonomy.root.id).update_all(permalink: permalink)
      end

      taxonomies
    end

    def permalinks
      Spree::Category.unscoped.pluck(:permalink).compact
    end

    it 'completes instead of aborting on the store-scoped unique index' do
      build_colliding_roots(2)

      expect { subject.invoke }.not_to raise_error
      expect(permalinks).to include('catalog', 'catalog-shop-1')
    end

    it 'gives every category a distinct permalink when more than two collide' do
      build_colliding_roots(3)
      subject.invoke

      expect(permalinks.uniq.size).to eq(permalinks.size)
    end

    it 'leaves categories with distinct permalinks alone' do
      taxonomy = create(:taxonomy, name: 'Solo', store: store)
      # A child keeps the root alive past the childless-root sweep.
      create(:category, name: 'Child', taxonomy: taxonomy, parent: taxonomy.root)
      Spree::Category.unscoped.where(id: taxonomy.root.id).update_all(permalink: 'untouched')

      subject.invoke

      expect(permalinks).to include('untouched')
    end

    it 'leaves the rewritten permalinks untouched on a second run' do
      build_colliding_roots(2)
      subject.invoke
      snapshot = Spree::Category.unscoped.order(:id).pluck(:id, :name, :permalink, :store_id)

      subject.reenable
      subject.invoke

      expect(Spree::Category.unscoped.order(:id).pluck(:id, :name, :permalink, :store_id)).to eq(snapshot)
    end
  end
end
