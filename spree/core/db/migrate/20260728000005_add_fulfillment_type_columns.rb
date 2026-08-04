class AddFulfillmentTypeColumns < ActiveRecord::Migration[7.2]
  def change
    # Defaults live on the model, not the DB; existing rows are backfilled by
    # the spree:migrate_shipping_to_delivery data task.
    add_column :spree_delivery_methods, :fulfillment_type, :string
    add_index :spree_delivery_methods, :fulfillment_type
    add_column :spree_delivery_methods, :fulfillment_provider, :string
    add_column :spree_delivery_methods, :pickup_point_provider, :string

    add_column :spree_fulfillments, :fulfillment_type, :string
    if connection.adapter_name.downcase.include?('postgresql')
      add_column :spree_fulfillments, :pickup_point_data, :jsonb
    else
      add_column :spree_fulfillments, :pickup_point_data, :json
    end
    add_reference :spree_fulfillments, :cart, null: true, if_not_exists: true

    create_table :spree_delivery_method_stock_locations do |t|
      t.references :delivery_method, null: false, index: false
      t.references :stock_location, null: false

      t.timestamps
    end
    add_index :spree_delivery_method_stock_locations, [:delivery_method_id, :stock_location_id],
              unique: true, name: 'idx_delivery_method_stock_locations_uniqueness'

    if connection.adapter_name.downcase.include?('postgresql')
      add_column :spree_products, :excluded_delivery_method_ids, :jsonb
    else
      add_column :spree_products, :excluded_delivery_method_ids, :json
    end
  end
end
