class CreateSpreeStores < ActiveRecord::Migration
  def change
    create_table :spree_stores do |t|
      t.string :name
      t.string :url
      t.text :meta_description
      t.text :meta_keywords
      t.string :seo_title
      t.string :mail_from_address
      t.string :default_currency

      t.timestamps
    end
  end
end
