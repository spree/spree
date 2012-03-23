class AddApiKeyToUsers < ActiveRecord::Migration
  def change
    add_column :spree_users, :api_key, :string, :limit => 40
  end
end
