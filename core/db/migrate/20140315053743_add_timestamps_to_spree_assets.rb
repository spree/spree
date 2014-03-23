class AddTimestampsToSpreeAssets < ActiveRecord::Migration
  def change
    add_column :spree_assets, :created_at, :datetime
    add_column :spree_assets, :updated_at, :datetime
  end
end
