class RenamePermalinkToSlugForProducts < ActiveRecord::Migration
  def change
    rename_column :spree_products, :permalink, :slug
  end
end
