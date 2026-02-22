class AddSessionIdToSpreeAssets < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_assets, :session_id, :string
  end
end
