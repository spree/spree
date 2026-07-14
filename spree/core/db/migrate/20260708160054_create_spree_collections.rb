class CreateSpreeCollections < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_collections do |t|
      t.string :name, null: false
      t.string :permalink
      t.boolean :automatic, null: false, default: false
      t.string :rules_match_policy, null: false, default: 'all'
      t.string :sort_order, null: false, default: 'manual'
      t.integer :position
      t.integer :products_count, null: false, default: 0
      t.references :store, null: false, index: true
      t.string :meta_title
      t.string :meta_description
      t.string :meta_keywords

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end
    add_index :spree_collections, [:store_id, :permalink], unique: true

    create_table :spree_product_collections do |t|
      t.references :product, null: false, index: true
      t.references :collection, null: false, index: true
      t.integer :position

      t.timestamps
    end
    add_index :spree_product_collections, [:collection_id, :product_id], unique: true,
              name: 'index_product_collections_on_collection_and_product'

    # STI table (type = Spree::CollectionRules::{AvailableOn,Sale,Tag}). NOT a rename of
    # spree_taxon_rules — that stays live for automatic taxons until the class rename phase.
    create_table :spree_collection_rules do |t|
      t.references :collection, null: false, index: true
      t.string :type, null: false
      t.string :value
      t.string :match_policy, null: false, default: 'is_equal_to'

      t.timestamps
    end
    add_index :spree_collection_rules, [:collection_id, :type]

    # Rails counter_cache for the number of collections a product belongs to.
    add_column :spree_products, :collections_count, :integer, null: false, default: 0

    # Mobility table-backend translations (mirrors spree_taxon_translations) for the
    # table-backed translatable fields. NOT ActionText-specific: the ActionText-backed
    # `description` is stored in the shared global action_text_rich_texts table.
    create_table :spree_collection_translations do |t|
      t.string :name
      t.string :permalink
      t.string :meta_title
      t.string :meta_description
      t.string :meta_keywords
      t.string :locale, null: false
      t.references :spree_collection, null: false, index: false

      t.timestamps null: false
    end
    add_index :spree_collection_translations, :locale, name: 'index_spree_collection_translations_on_locale'
    add_index :spree_collection_translations, [:spree_collection_id, :locale], unique: true,
              name: 'index_collection_translations_on_collection_and_locale'
  end
end
