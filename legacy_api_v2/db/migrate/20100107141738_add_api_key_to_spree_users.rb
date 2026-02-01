class AddApiKeyToSpreeUsers < ActiveRecord::Migration[4.2]
  def change
    unless defined?(User)
      add_column :spree_users, :api_key, :string, limit: 40
    end
  end
end
