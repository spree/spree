class CreateSpreePages < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_pages do |t|
      t.column :title, :string, null: false
      t.column :meta_title, :string
      t.column :meta_description, :text
      t.column :visible, :boolean, default: false
      t.column :slug, :string
      t.column :kind, :string
      t.column :locale, :string

      t.references :sections, polymorphic: true

      t.belongs_to :store

      t.timestamps
    end
  end
end
