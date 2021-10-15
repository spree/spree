class AddMetadataToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_users, :public_metadata, :text
    add_column :spree_users, :private_metadata, :text
  end
end
