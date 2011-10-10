class AddApiKeyToUsers < ActiveRecord::Migration
  def self.up
    add_column "spree_users", "api_key", :string, :limit => 40
  end

  def self.down
    remove_column "spree_users", "api_key"
  end
end
