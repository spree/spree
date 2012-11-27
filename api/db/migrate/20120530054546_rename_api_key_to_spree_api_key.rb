class RenameApiKeyToSpreeApiKey < ActiveRecord::Migration
  def change
    unless defined?(User)
      rename_column :spree_users, :api_key, :spree_api_key
    end
  end
end
