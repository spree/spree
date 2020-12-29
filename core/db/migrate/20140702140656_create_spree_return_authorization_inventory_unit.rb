class CreateSpreeReturnAuthorizationInventoryUnit < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_return_authorization_inventory_units do |t|
      t.integer :return_authorization_id
      t.integer :inventory_unit_id
      t.integer :exchange_variant_id
      t.datetime :received_at

      t.timestamps null: false, precision: 6
    end
  end
end
