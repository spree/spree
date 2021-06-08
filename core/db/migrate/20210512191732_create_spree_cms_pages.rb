class CreateSpreeCmsPages < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_cms_pages do |t|
      t.column :title, :string, null: false
      t.column :meta_title, :string
      t.column :content, :text
      t.column :meta_description, :text
      t.column :visible, :boolean, default: true
      t.column :slug, :string
      t.column :type, :string
      t.column :locale, :string

      t.belongs_to :store

      t.timestamps
    end

    add_index :spree_cms_pages, [:title, :type, :store_id]
    add_index :spree_cms_pages, [:slug, :store_id]
    add_index :spree_cms_pages, [:store_id, :locale, :type]
  end
end
