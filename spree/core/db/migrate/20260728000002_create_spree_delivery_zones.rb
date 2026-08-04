class CreateSpreeDeliveryZones < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_delivery_zones do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :description
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end
    add_index :spree_delivery_zones, [:store_id, :name], unique: true

    create_table :spree_delivery_zone_members do |t|
      t.references :delivery_zone, null: false
      t.string :member_type, null: false
      t.references :country, null: true
      t.references :state, null: true
      t.string :postal_code_prefix
      t.string :postal_code_from
      t.string :postal_code_to

      t.timestamps
    end
  end
end
