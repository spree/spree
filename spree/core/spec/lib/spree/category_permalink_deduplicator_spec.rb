require 'spec_helper'
require 'spree/category_permalink_deduplicator'

RSpec.describe Spree::CategoryPermalinkDeduplicator do
  let(:store) { @default_store }

  # Rows are staged with store_id NULL — the genuine pre-backfill state of a store
  # upgrading from 5.5. The unique index tolerates them (NULLs compare distinct),
  # while the deduplicator still sees the collision because it resolves each
  # category's store through its taxonomy. Dropping the index instead would issue
  # DDL inside the example's transaction, which MySQL commits implicitly and so
  # destroys the savepoint the suite rolls back to.
  def stage(category, permalink)
    Spree::Category.unscoped.where(id: category.id).update_all(permalink: permalink, store_id: nil)
  end

  it 'separates duplicate permalinks and cascades to descendants' do
    taxonomy_a = create(:taxonomy, name: 'Shop A', store: store)
    taxonomy_b = create(:taxonomy, name: 'Shop B', store: store)

    child_a = create(:category, name: 'Kids A', taxonomy: taxonomy_a, parent: taxonomy_a.root)
    child_b = create(:category, name: 'Kids B', taxonomy: taxonomy_b, parent: taxonomy_b.root)

    # Both taxonomies own a "catalog" root — legal before 6.0, colliding after.
    stage(taxonomy_a.root, 'catalog')
    stage(taxonomy_b.root, 'catalog')
    stage(child_a, 'catalog/kids-a')
    stage(child_b, 'catalog/kids-b')

    expect(described_class.new.call).to eq(1)

    permalinks = Spree::Category.unscoped.pluck(:id, :permalink).to_h
    expect(permalinks[taxonomy_a.root.id]).to eq('catalog')
    expect(permalinks[taxonomy_b.root.id]).to eq('catalog-shop-b')

    # The moved root's child follows it rather than keeping a path its parent
    # no longer has.
    expect(permalinks[child_b.id]).to eq('catalog-shop-b/kids-b')
    expect(permalinks[child_a.id]).to eq('catalog/kids-a')
  end

  it 'falls back to a numeric suffix when the taxonomy-named variant is taken' do
    taxonomy_a = create(:taxonomy, name: 'Shop A', store: store)
    taxonomy_b = create(:taxonomy, name: 'Shop B', store: store)
    # An unrelated category already occupies the name the suffix would produce.
    squatter = create(:taxonomy, name: 'Squatter', store: store)

    stage(taxonomy_a.root, 'catalog')
    stage(taxonomy_b.root, 'catalog')
    stage(squatter.root, 'catalog-shop-b')

    described_class.new.call

    permalinks = Spree::Category.unscoped.pluck(:permalink).compact
    expect(permalinks.uniq.size).to eq(permalinks.size)
    expect(permalinks).to include('catalog-shop-b-2')
  end

  it 'is idempotent' do
    taxonomy_a = create(:taxonomy, name: 'A', store: store)
    taxonomy_b = create(:taxonomy, name: 'B', store: store)
    stage(taxonomy_a.root, 'dup')
    stage(taxonomy_b.root, 'dup')

    described_class.new.call
    after_first_run = Spree::Category.unscoped.order(:id).pluck(:id, :permalink)

    expect(described_class.new.call).to eq(0)
    expect(Spree::Category.unscoped.order(:id).pluck(:id, :permalink)).to eq(after_first_run)
  end

  it 'leaves distinct permalinks untouched' do
    taxonomy = create(:taxonomy, name: 'Solo', store: store)
    stage(taxonomy.root, 'untouched')

    expect(described_class.new.call).to eq(0)
    expect(Spree::Category.unscoped.where(id: taxonomy.root.id).pick(:permalink)).to eq('untouched')
  end

  # The storefront resolves a category through the translations table, which has
  # no uniqueness constraint — so a collision there survives the base-column pass
  # and makes the localized lookup return whichever row it reaches first.
  it 'separates colliding translated permalinks' do
    taxonomy_a = create(:taxonomy, name: 'Shop A', store: store)
    taxonomy_b = create(:taxonomy, name: 'Shop B', store: store)

    Spree::Category::Translation.create!(spree_category_id: taxonomy_a.root.id, locale: 'pl', permalink: 'katalog')
    Spree::Category::Translation.create!(spree_category_id: taxonomy_b.root.id, locale: 'pl', permalink: 'katalog')
    stage(taxonomy_a.root, 'catalog')
    stage(taxonomy_b.root, 'catalog')

    described_class.new.call

    translated = Spree::Category::Translation.where(locale: 'pl').pluck(:permalink)
    expect(translated.uniq.size).to eq(translated.size)
  end

  it 'separates translated permalinks even when the base column is already unique' do
    alpha = create(:category, name: 'Alpha', store: store)
    beta = create(:category, name: 'Beta', store: store)
    Spree::Category::Translation.create!(spree_category_id: alpha.id, locale: 'pl', permalink: 'dup')
    Spree::Category::Translation.create!(spree_category_id: beta.id, locale: 'pl', permalink: 'dup')

    described_class.new.call

    translated = Spree::Category::Translation.where(locale: 'pl').pluck(:permalink)
    expect(translated.uniq.size).to eq(translated.size)
  end

  it 'cascades child translations when a translated parent permalink moves' do
    alpha = create(:category, name: 'Alpha', store: store)
    beta = create(:category, name: 'Beta', store: store)
    child = create(:category, name: 'Kids', parent: beta, store: store)

    Spree::Category::Translation.create!(spree_category_id: alpha.id, locale: 'pl', permalink: 'katalog')
    Spree::Category::Translation.create!(spree_category_id: beta.id, locale: 'pl', permalink: 'katalog')
    Spree::Category::Translation.create!(spree_category_id: child.id, locale: 'pl', permalink: 'katalog/dzieci')

    described_class.new.call

    moved_root = Spree::Category::Translation.find_by(spree_category_id: beta.id, locale: 'pl').permalink
    child_path = Spree::Category::Translation.find_by(spree_category_id: child.id, locale: 'pl').permalink

    expect(child_path).to start_with("#{moved_root}/")
  end

  # SQL returns duplicate groups in no defined order. If a colliding child is
  # rewritten before its colliding parent, it gets a suffix of its own and is
  # then re-prefixed by the parent's cascade, yielding "catalog-b/kids-b".
  it 'rewrites a parent before its children, whatever order the groups arrive in' do
    taxonomy_a = create(:taxonomy, name: 'Shop A', store: store)
    taxonomy_b = create(:taxonomy, name: 'Shop B', store: store)
    kids_a = create(:category, name: 'Kids', taxonomy: taxonomy_a, parent: taxonomy_a.root)
    kids_b = create(:category, name: 'Kids', taxonomy: taxonomy_b, parent: taxonomy_b.root)

    # Parents collide, and so do their children.
    stage(taxonomy_a.root, 'catalog')
    stage(taxonomy_b.root, 'catalog')
    stage(kids_a, 'catalog/kids')
    stage(kids_b, 'catalog/kids')

    described_class.new.call

    permalinks = Spree::Category.unscoped.pluck(:id, :permalink).to_h
    expect(permalinks[kids_b.id]).to eq("#{permalinks[taxonomy_b.root.id]}/kids")
    expect(permalinks[kids_a.id]).to eq("#{permalinks[taxonomy_a.root.id]}/kids")

    all = permalinks.values.compact
    expect(all.uniq.size).to eq(all.size)
  end

  # Re-prefixing a subtree can move a descendant onto a path another row already
  # holds. That collision is created *by* the dedup pass, so a single snapshot of
  # the duplicate groups never sees it — and the unique index then cannot be
  # created, which is the exact failure this class exists to prevent.
  it 'resolves collisions its own cascade creates' do
    taxonomy_a = create(:taxonomy, name: 'Shop A', store: store)
    taxonomy_b = create(:taxonomy, name: 'Shop B', store: store)
    kids = create(:category, name: 'Kids', taxonomy: taxonomy_b, parent: taxonomy_b.root)
    squatter = create(:category, name: 'Squatter', taxonomy: taxonomy_a, parent: taxonomy_a.root)

    stage(taxonomy_a.root, 'catalog')
    stage(taxonomy_b.root, 'catalog')
    stage(kids, 'catalog/kids')
    # Already sits on the path the cascade will move `kids` onto.
    stage(squatter, 'catalog-shop-b/kids')

    described_class.new.call

    permalinks = Spree::Category.unscoped.pluck(:permalink).compact
    expect(permalinks.uniq.size).to eq(permalinks.size)
  end
end
