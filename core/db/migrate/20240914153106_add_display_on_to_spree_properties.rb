class AddDisplayOnToSpreeProperties < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_properties, :display_on, :string, default: 'both', if_not_exists: true
  end
end
