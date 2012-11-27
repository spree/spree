class AddPositionToTaxonomies < ActiveRecord::Migration
  def change
  	add_column :spree_taxonomies, :position, :integer, :default => 0
  end
end
