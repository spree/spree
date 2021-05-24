class CreateSpreeCmsSections < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_cms_sections do |t|
      t.column :name, :string, null: false
      t.column :title, :string
      t.column :subtitle, :string
      t.column :button_text, :string
      t.column :content, :text
      t.column :width, :string
      t.column :kind, :string
      t.column :destination, :string
      t.column :position, :integer

      t.references :linked_resource, polymorphic: true, index: { name: 'index_spree_cms_sections_on_linked_resource' }

      t.belongs_to :cms_page

      t.timestamps
    end
  end
end
