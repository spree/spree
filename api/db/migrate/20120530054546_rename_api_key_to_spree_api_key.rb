class RenameApiKeyToSpreeApiKey < ActiveRecord::Migration
  def up
    rename_column :spree_users, :api_key, :spree_api_key
  end

  def down
    rename_column :spree_users, :spree_api_key, :api_key
  end
end
