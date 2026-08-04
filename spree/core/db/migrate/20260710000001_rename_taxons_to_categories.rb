class RenameTaxonsToCategories < ActiveRecord::Migration[7.2]
  def change
    rename_table :spree_taxons, :spree_categories
    rename_table :spree_products_taxons, :spree_product_categories
    rename_column :spree_product_categories, :taxon_id, :category_id

    # Promotion↔category join (Spree::PromotionRuleCategory) and the Mobility
    # translations table follow the same rename now, so no class needs a
    # table_name/foreign_key pin. (spree_taxon_rules + spree_prototype_taxons keep
    # taxon_id: the former is dropped in 6.1, the latter renamed by 6.0-product-types.)
    rename_table :spree_promotion_rule_taxons, :spree_promotion_rule_categories
    rename_column :spree_promotion_rule_categories, :taxon_id, :category_id

    rename_table :spree_taxon_translations, :spree_category_translations
    rename_column :spree_category_translations, :spree_taxon_id, :spree_category_id

    # store_id already exists on spree_taxons (shipped 5.6) and carries over on the
    # rename — do NOT re-add it. Backfill first:
    #   bundle exec rake spree:taxons:backfill_store_id

    # Category counter caches: keep the descendant-inclusive products_count (already
    # present); drop the direct classification_count (only the legacy Rails admin
    # read it). Rename the product-side counter to categories_count
    # (collections_count was added additively in Phase 1).
    remove_column :spree_categories, :classification_count, :integer, default: 0, null: false
    rename_column :spree_products, :classification_count, :categories_count
  end
end
