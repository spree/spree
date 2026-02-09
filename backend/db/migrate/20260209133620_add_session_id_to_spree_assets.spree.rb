# This migration comes from spree (originally 20250509143831)
class AddSessionIdToSpreeAssets < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_assets, :session_id, :string
  end
end
