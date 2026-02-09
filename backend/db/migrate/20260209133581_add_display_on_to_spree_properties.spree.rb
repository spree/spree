# This migration comes from spree (originally 20240914153106)
class AddDisplayOnToSpreeProperties < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_properties, :display_on, :string, default: 'both', if_not_exists: true
  end
end
