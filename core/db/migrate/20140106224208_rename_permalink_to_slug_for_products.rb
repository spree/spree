class RenamePermalinkToSlugForProducts < ActiveRecord::Migration[4.2]
  def change
    rename_column :spree_products, :permalink, :slug
  end
end
