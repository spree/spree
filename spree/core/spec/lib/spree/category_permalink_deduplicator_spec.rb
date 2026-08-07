require 'spec_helper'
require 'spree/category_permalink_deduplicator'

RSpec.describe Spree::CategoryPermalinkDeduplicator do
  let(:store) { @default_store }
  let(:index_name) { 'index_spree_categories_on_permalink_and_store_id' }

  # The duplicates being fixed can only exist while the index is absent — which is
  # exactly the pre-migration state this class runs against.
  around do |example|
    conn = ActiveRecord::Base.connection
    conn.remove_index :spree_categories, name: index_name, if_exists: true
    example.run
    conn.add_index :spree_categories, %i[permalink store_id], name: index_name, unique: true, if_not_exists: true
  end

  it 'separates duplicate permalinks and cascades to descendants' do
    tax_a = create(:taxonomy, name: 'Shop A', store: store)
    tax_b = create(:taxonomy, name: 'Shop B', store: store)

    # A 5.6 store post-backfill: store_id populated, two "catalog" roots, each
    # with a child whose permalink is prefixed by its parent.
    root_a, root_b = tax_a.root, tax_b.root
    child_a = Spree::Category.new(name: 'Kids A', taxonomy_id: tax_a.id, parent_id: root_a.id, store_id: store.id)
    child_a.save!(validate: false)
    child_b = Spree::Category.new(name: 'Kids B', taxonomy_id: tax_b.id, parent_id: root_b.id, store_id: store.id)
    child_b.save!(validate: false)

    Spree::Category.unscoped.where(id: root_a.id).update_all(permalink: 'catalog', store_id: store.id)
    Spree::Category.unscoped.where(id: root_b.id).update_all(permalink: 'catalog', store_id: store.id)
    Spree::Category.unscoped.where(id: child_a.id).update_all(permalink: 'catalog/kids-a', store_id: store.id)
    Spree::Category.unscoped.where(id: child_b.id).update_all(permalink: 'catalog/kids-b', store_id: store.id)

    renamed = described_class.new.call
    puts "renamed: #{renamed}"

    permalinks = Spree::Category.unscoped.where(store_id: store.id).pluck(:id, :permalink).to_h
    puts "root_a:  #{permalinks[root_a.id].inspect}"
    puts "root_b:  #{permalinks[root_b.id].inspect}"
    puts "child_a: #{permalinks[child_a.id].inspect}"
    puts "child_b: #{permalinks[child_b.id].inspect}"

    all = Spree::Category.unscoped.where(store_id: store.id).pluck(:permalink).compact
    expect(all.uniq.size).to eq(all.size), "duplicates remain: #{all.inspect}"

    # The moved root's child must follow it, not keep the old prefix.
    expect(permalinks[child_b.id]).to start_with("#{permalinks[root_b.id]}/")
  end

  it 'is idempotent' do
    tax_a = create(:taxonomy, name: 'A', store: store)
    tax_b = create(:taxonomy, name: 'B', store: store)
    Spree::Category.unscoped.where(id: [tax_a.root.id, tax_b.root.id]).update_all(permalink: 'dup', store_id: store.id)

    described_class.new.call
    first = Spree::Category.unscoped.order(:id).pluck(:id, :permalink)
    expect(described_class.new.call).to eq(0)
    expect(Spree::Category.unscoped.order(:id).pluck(:id, :permalink)).to eq(first)
  end
end
