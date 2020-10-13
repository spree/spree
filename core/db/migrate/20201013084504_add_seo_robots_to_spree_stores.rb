class AddSeoRobotsToSpreeStores < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_stores, :seo_robots, :string
  end
end
