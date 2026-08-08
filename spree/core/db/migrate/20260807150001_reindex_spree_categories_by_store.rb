require 'spree/category_permalink_deduplicator'

class ReindexSpreeCategoriesByStore < ActiveRecord::Migration[8.1]
  PERMALINK_INDEX = 'index_spree_categories_on_permalink_and_store_id'.freeze

  # Categories are store-owned in 6.0, so uniqueness is scoped to the store rather
  # than the taxonomy. The old taxonomy-scoped indexes stop constraining anything
  # once spree:migrate_taxons_to_categories_and_collections nulls taxonomy_id,
  # because SQL treats NULLs as distinct in unique indexes.
  #
  # The permalink is the category's full path ("men/clothing/shirts"), so it
  # already encodes the hierarchy: scoping it by parent_id was always redundant,
  # and (permalink, store_id) is the real constraint. Name uniqueness is dropped
  # entirely — two categories may share a name in different branches, which their
  # permalinks already distinguish.
  #
  # The duplicates are resolved here rather than in the upgrade rake task. A 5.6
  # store has already run spree:taxons:backfill_store_id (5.5 -> 5.6), so its
  # categories carry a store_id by the time this runs, and any cross-taxonomy
  # permalink collision would fail index creation and block the deploy.
  def up
    remove_index :spree_categories, name: 'index_spree_categories_on_name_and_parent_id_and_taxonomy_id', if_exists: true
    remove_index :spree_categories, name: 'idx_on_permalink_parent_id_taxonomy_id_0aed458a0c', if_exists: true

    renamed = Spree::CategoryPermalinkDeduplicator.new(connection).call
    say "resolved #{renamed} duplicate category permalinks", true if renamed.positive?

    add_index :spree_categories, %i[permalink store_id],
              name: PERMALINK_INDEX, unique: true, if_not_exists: true
  end

  def down
    remove_index :spree_categories, name: PERMALINK_INDEX, if_exists: true

    add_index :spree_categories, %i[name parent_id taxonomy_id],
              name: 'index_spree_categories_on_name_and_parent_id_and_taxonomy_id',
              unique: true, if_not_exists: true
    add_index :spree_categories, %i[permalink parent_id taxonomy_id],
              name: 'idx_on_permalink_parent_id_taxonomy_id_0aed458a0c',
              unique: true, if_not_exists: true
  end
end
