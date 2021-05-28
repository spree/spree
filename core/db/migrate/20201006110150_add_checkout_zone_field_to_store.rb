class AddCheckoutZoneFieldToStore < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :checkout_zone_id)
      add_column :spree_stores, :checkout_zone_id, :integer

      Spree::Store.reset_column_information

      default_zone = Spree::Zone.default_checkout_zone
      Spree::Store.update_all(checkout_zone_id: default_zone.id) if default_zone.present?
    end
  end
end
