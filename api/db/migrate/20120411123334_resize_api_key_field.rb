class ResizeApiKeyField < ActiveRecord::Migration[4.2]
  def change
    unless defined?(User)
      change_column :spree_users, :api_key, :string, limit: 48
    end
  end
end
