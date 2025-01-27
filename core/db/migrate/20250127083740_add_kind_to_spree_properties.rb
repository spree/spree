class AddKindToSpreeProperties < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_properties, :kind, :integer, default: 0, if_not_exists: true
  end
end
