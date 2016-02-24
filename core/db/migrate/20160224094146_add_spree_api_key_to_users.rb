class AddSpreeApiKeyToUsers < ActiveRecord::Migration
  def change
    unless defined?(User)
      unless column_exists?(:spree_users, :spree_api_key, :string)
        add_column :spree_users, :spree_api_key, :string, limit: 48
      end
      unless index_exists?(:spree_users, :spree_api_key)
        add_index :spree_users, :spree_api_key
      end
    end
  end
end
