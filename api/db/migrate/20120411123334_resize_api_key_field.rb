class ResizeApiKeyField < ActiveRecord::Migration
  def change
    if table_exists?(:spree_users)
      change_column :spree_users, :api_key, :string, :limit => 48
    end
  end
end
