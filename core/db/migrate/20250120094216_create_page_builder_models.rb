class CreatePageBuilderModels < ActiveRecord::Migration[6.1]
  def change
    if !table_exists?(:spree_themes)
      create_table :spree_themes do |t|
        t.string :name
        t.references :store, null: false, index: true
        t.boolean :default, default: false, null: false
        t.boolean :ready, default: true
        t.string :type, default: 'Spree::Themes::Default', null: false
        t.references :parent
        t.text :preferences

        t.timestamps
        t.datetime :deleted_at

        t.index ['deleted_at'], name: 'index_spree_themes_on_deleted_at'
        t.index ['store_id', 'default'], name: 'index_spree_themes_on_store_id_and_default', unique: true, where: "((deleted_at IS NULL) AND (\"default\" = true))"
      end
    end

    if !table_exists?(:spree_pages)
      create_table :spree_pages do |t|
        t.references :pageable, polymorphic: true, null: false
        t.string :type, null: false
        t.string :slug
        t.string :name, null: false
        t.string :meta_title
        t.string :meta_description
        t.string :meta_keywords
        t.references :parent
        t.text :preferences

        t.timestamps
        t.datetime :deleted_at

        t.index ['pageable_id', 'name'], name: 'index_spree_pages_on_pageable_id_and_name'
        t.index ['pageable_id', 'pageable_type', 'slug'], name: 'index_spree_pages_on_pageable_id_and_pageable_type_and_slug', unique: true, where: '((deleted_at IS NULL) AND (slug IS NOT NULL))'
        t.index ['pageable_id', 'pageable_type', 'type'], name: 'index_spree_pages_on_pageable_id_and_pageable_type_and_type'
        t.index ['pageable_id', 'pageable_type'], name: 'index_spree_pages_on_pageable_id_and_pageable_type'
      end
    end

    if !table_exists?(:spree_page_sections)
      create_table :spree_page_sections do |t|
        t.references :pageable, polymorphic: true, null: false, index: true
        t.string :type, null: false
        t.string :name, null: false
        t.integer :position, default: 1, null: false
        t.integer :page_links_count, default: 0
        t.text :preferences

        t.timestamps
        t.datetime :deleted_at

        t.index ['pageable_id', 'pageable_type', 'position'], name: 'index_spree_page_sections_on_pageable_w_position'
      end
    end

    if !table_exists?(:spree_page_blocks)
      create_table :spree_page_blocks do |t|
        t.references :section, null: false, index: true
        t.string :name, null: false
        t.integer :position, default: 1, null: false
        t.string :type, null: false
        t.integer :page_links_count, default: 0
        t.text :preferences

        t.timestamps
        t.datetime :deleted_at

        t.index ['section_id', 'position'], name: 'index_spree_page_blocks_on_section_w_position'
      end
    end

    if !table_exists?(:spree_page_links)
      create_table :spree_page_links do |t|
        t.references :parent, polymorphic: true, index: true
        t.references :linkable, polymorphic: true, index: true
        t.string :label
        t.string :url
        t.boolean :open_in_new_tab, default: false
        t.integer :position, default: 1, null: false

        t.timestamps

        t.index ['parent_id'], name: 'index_spree_page_links_on_parent_id'
      end
    end
  end
end
