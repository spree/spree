class CreateSpreeSections < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_cms_section_rte do |t|
      t.column :content, :text
      t.column :width, :text
      t.column :position, :integer
      t.column :linked_resource_type, :string, default: 'None'
      t.column :linked_resource_id, :integer

      t.belongs_to :page

      t.timestamps
    end

    add_index :spree_sections, [:linked_resource_type, :linked_resource_id], name: 'index_spree_sections_on_linked_resource'
  end
end
