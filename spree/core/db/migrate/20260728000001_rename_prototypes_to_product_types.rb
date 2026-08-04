class RenamePrototypesToProductTypes < ActiveRecord::Migration[7.2]
  def change
    # Old-name indexes are dropped up front and re-added under stable names after
    # the renames — Rails' automatic index renaming would generate names over
    # PostgreSQL's 63-char identifier limit for the composite ones.
    remove_index :spree_option_type_prototypes, column: [:prototype_id, :option_type_id], unique: true,
                 name: 'spree_option_type_prototypes_prototype_id_option_type_id', if_exists: true
    remove_index :spree_option_type_prototypes, column: :prototype_id,
                 name: 'index_spree_option_type_prototypes_on_prototype_id', if_exists: true
    remove_index :spree_option_type_prototypes, column: :option_type_id,
                 name: 'index_spree_option_type_prototypes_on_option_type_id', if_exists: true
    remove_index :spree_prototype_taxons, column: [:prototype_id, :taxon_id],
                 name: 'index_spree_prototype_taxons_on_prototype_id_and_taxon_id', if_exists: true
    remove_index :spree_prototype_taxons, column: :prototype_id,
                 name: 'index_spree_prototype_taxons_on_prototype_id', if_exists: true
    remove_index :spree_prototype_taxons, column: :taxon_id,
                 name: 'index_spree_prototype_taxons_on_taxon_id', if_exists: true

    rename_table :spree_prototypes, :spree_product_types
    rename_table :spree_option_type_prototypes, :spree_option_type_product_types
    rename_table :spree_prototype_taxons, :spree_product_type_categories

    rename_column :spree_option_type_product_types, :prototype_id, :product_type_id
    rename_column :spree_product_type_categories, :prototype_id, :product_type_id
    rename_column :spree_product_type_categories, :taxon_id, :category_id

    add_index :spree_option_type_product_types, [:product_type_id, :option_type_id], unique: true,
              name: 'index_option_type_product_types_uniqueness'
    add_index :spree_option_type_product_types, :option_type_id,
              name: 'index_option_type_product_types_on_option_type_id'
    add_index :spree_product_type_categories, [:product_type_id, :category_id], unique: true,
              name: 'index_product_type_categories_uniqueness'
    add_index :spree_product_type_categories, :category_id,
              name: 'index_product_type_categories_on_category_id'

    add_reference :spree_products, :product_type, null: true, if_not_exists: true
    add_reference :spree_product_types, :store, null: true, if_not_exists: true

    if connection.adapter_name.downcase.include?('postgresql')
      add_column :spree_product_types, :fulfillment_types, :jsonb
    else
      add_column :spree_product_types, :fulfillment_types, :json
    end

    add_column :spree_product_types, :products_count, :integer, null: false, default: 0

    create_table :spree_product_type_translations do |t|
      t.string :name
      t.string :locale, null: false
      t.references :spree_product_type, null: false, index: false

      t.timestamps null: false
    end
    add_index :spree_product_type_translations, :locale,
              name: 'index_spree_product_type_translations_on_locale'
    add_index :spree_product_type_translations, [:spree_product_type_id, :locale], unique: true,
              name: 'index_product_type_translations_on_product_type_and_locale'
  end
end
