class AddMissingPageBuilderIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_themes, %w[store_id default], name: 'index_spree_themes_on_store_id_and_default', if_not_exists: true
    add_index :spree_page_links, %w[parent_type parent_id position], name: 'index_spree_page_links_parent_with_position', if_not_exists: true
    add_index :spree_page_blocks, :deleted_at, if_not_exists: true
  end
end
