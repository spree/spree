class AddUpdatedAtToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :updated_at, :datetime
  end
end
