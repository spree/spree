class CreateStoreTranslations < ActiveRecord::Migration[6.1]
  def change
    if ActiveRecord::Base.connection.table_exists?('spree_store_translations')
      # manually check for index since Rails if_exists does not always work correctly
      if ActiveRecord::Migration.connection.index_exists?(:spree_store_translations, :spree_store_id)
        remove_index :spree_store_translations, column: :spree_store_id, if_exists: true
      end

      add_column :spree_store_translations, :url, :string
      add_column :spree_store_translations, :default_currency, :string
      add_column :spree_store_translations, :supported_currencies, :string
      add_column :spree_store_translations, :facebook, :string
      add_column :spree_store_translations, :twitter, :string
      add_column :spree_store_translations, :instagram, :string
      add_column :spree_store_translations, :customer_support_email, :string
      add_column :spree_store_translations, :default_country_id, :integer
      add_column :spree_store_translations, :description, :text
      add_column :spree_store_translations, :address, :text
      add_column :spree_store_translations, :contact_phone, :string
      add_column :spree_store_translations, :new_order_notifications_email, :string
      add_column :spree_store_translations, :checkout_zone_id, :integer
    else
      create_table :spree_store_translations do |t|
        # Translated attribute(s)
        t.string :name
        t.string :url
        t.text :meta_description
        t.text :meta_keywords
        t.string :seo_title
        t.string :default_currency
        t.string :supported_currencies
        t.string :facebook
        t.string :twitter
        t.string :instagram
        t.string :customer_support_email
        t.integer :default_country_id
        t.text :description
        t.text :address
        t.string :contact_phone
        t.string :new_order_notifications_email
        t.integer :checkout_zone_id

        t.string  :locale, null: false
        t.references :spree_store, null: false, foreign_key: true, index: false

        t.timestamps null: false
      end

      add_index :spree_store_translations, :locale, name: :index_spree_store_translations_on_locale
    end

    add_index :spree_store_translations, [:spree_store_id, :locale], name: :index_spree_store_translations_on_spree_store_id_locale, unique: true
  end
end
