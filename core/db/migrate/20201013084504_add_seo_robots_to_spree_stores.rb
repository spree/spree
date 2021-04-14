class AddSeoRobotsToSpreeStores < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_stores, :seo_robots, :string unless column_exists?(:spree_stores, :seo_robots)
  end
end
