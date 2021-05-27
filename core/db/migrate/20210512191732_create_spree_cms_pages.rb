class CreateSpreeCmsPages < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_cms_pages do |t|
      t.column :title, :string, null: false
      t.column :meta_title, :string
      t.column :content, :text
      t.column :meta_description, :text
      t.column :visible, :boolean, default: false
      t.column :slug, :string
      t.column :type, :string
      t.column :locale, :string

      t.belongs_to :store

      t.timestamps
    end
  end
end
