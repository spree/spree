class CreateSpreeStores < ActiveRecord::Migration[4.2]
  def change
    if data_source_exists?(:spree_stores)
      rename_column :spree_stores, :domains, :url
      rename_column :spree_stores, :email, :mail_from_address
      add_column :spree_stores, :meta_description, :text
      add_column :spree_stores, :meta_keywords, :text
      add_column :spree_stores, :seo_title, :string
    else
      create_table :spree_stores do |t|
        t.string :name
        t.string :url
        t.text :meta_description
        t.text :meta_keywords
        t.string :seo_title
        t.string :mail_from_address
        t.string :default_currency
        t.string :code
        t.boolean :default, default: false, null: false

        t.timestamps null: false, precision: 6
      end
    end
  end
end
