# This migration comes from spree (originally 20250123135358)
class AddCustomCodeFieldsToSpreeStore < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_stores, :storefront_custom_code_head, :text
    add_column :spree_stores, :storefront_custom_code_body_start, :text
    add_column :spree_stores, :storefront_custom_code_body_end, :text
  end
end
