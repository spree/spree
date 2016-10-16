class AddCreatedAtToVariant < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_variants, :created_at, :datetime
    Spree::Variant.reset_column_information
    Spree::Variant.where.not(updated_at: nil).update_all('created_at = updated_at')
    Spree::Variant.where(updated_at: nil).update_all(created_at: Time.current, updated_at: Time.current)
  end
end
