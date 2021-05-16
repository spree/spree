class CreateSpreeCmsSections < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_cms_sections do |t|
      t.column :name, :string, null: false
      t.column :title, :string
      t.column :subtitle, :string
      t.column :content, :text
      t.column :width, :string, default: 'Full'
      t.column :kind, :string, default: 'Text Block'
      t.column :position, :integer
      t.column :linked_resource_type, :string, default: 'none'
      t.column :linked_resource_id, :integer

      t.belongs_to :cms_page

      t.timestamps
    end

    add_index :spree_cms_sections, [:linked_resource_type, :linked_resource_id], name: 'index_spree_cms_sections_on_linked_resource'
  end
end
