class AddUpdatedAtToVariants < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_variants, :updated_at, :datetime
  end
end
