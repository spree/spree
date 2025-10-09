class AddTranslationsToPageBuilderComponents < ActiveRecord::Migration[6.1]
  def change
    # Page Translations
    create_table :spree_page_translations do |t|
      t.string :title
      t.text :content
      t.string :meta_title
      t.text :meta_description
      t.string :meta_keywords
      t.string :slug
      t.string :locale, null: false
      t.references :spree_page, null: false, foreign_key: true, index: false
      t.timestamps
    end
    add_index :spree_page_translations, :locale, name: :index_spree_page_translations_on_locale
    add_index :spree_page_translations, [:spree_page_id, :locale], name: :index_spree_page_translations_on_page_id_and_locale, unique: true
    add_index :spree_page_translations, :slug, name: :index_spree_page_translations_on_slug

    # Page Section Translations
    create_table :spree_page_section_translations do |t|
      t.string :title
      t.text :content
      t.string :settings
      t.string :locale, null: false
      t.references :spree_page_section, null: false, foreign_key: true, index: false
      t.timestamps
    end
    add_index :spree_page_section_translations, :locale, name: :index_spree_page_section_translations_on_locale
    add_index :spree_page_section_translations, [:spree_page_section_id, :locale], 
              name: :index_spree_page_section_translations_on_section_id_and_locale, unique: true

    # Page Block Translations
    create_table :spree_page_block_translations do |t|
      t.string :title
      t.text :content
      t.string :settings
      t.string :locale, null: false
      t.references :spree_page_block, null: false, foreign_key: true, index: false
      t.timestamps
    end
    add_index :spree_page_block_translations, :locale, name: :index_spree_page_block_translations_on_locale
    add_index :spree_page_block_translations, [:spree_page_block_id, :locale], 
              name: :index_spree_page_block_translations_on_block_id_and_locale, unique: true
  end
end
