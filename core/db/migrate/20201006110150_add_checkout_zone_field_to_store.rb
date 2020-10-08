class AddCheckoutZoneFieldToStore < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_stores, :checkout_zone_id)
      add_reference :spree_stores, :checkout_zone, { references: :spree_zones, index: true }

      Spree::Store.reset_column_information
      Spree::Store.update_all(checkout_zone_id: Spree::Zone.find_by(name: Spree::Config[:checkout_zone])&.id)
    end
  end
end
