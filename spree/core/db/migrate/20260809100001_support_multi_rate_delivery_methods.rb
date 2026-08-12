class SupportMultiRateDeliveryMethods < ActiveRecord::Migration[8.1]
  def change
    # A carrier provider now yields one rate per service, so a fulfillment can
    # hold several rates for the same delivery method (decisions.md
    # 2026-08-09). Keep a non-unique index for the lookup path.
    remove_index :spree_delivery_rates, name: 'spree_delivery_rates_join_index'
    add_index :spree_delivery_rates, [:fulfillment_id, :delivery_method_id],
              name: 'spree_delivery_rates_join_index'

    # Provider-priced rates carry their own display name ("UPS Ground" or a
    # merchant label override); calculator rates leave it null and fall back
    # to the delivery method's name.
    add_column :spree_delivery_rates, :name, :string

    # Method-level handling fee applied on top of provider quotes — the
    # default when a service row doesn't override it.
    add_column :spree_delivery_methods, :markup_flat, :decimal, precision: 10, scale: 2, default: 0
    add_column :spree_delivery_methods, :markup_percent, :decimal, precision: 8, scale: 2, default: 0

    create_table :spree_delivery_method_services do |t|
      t.references :delivery_method, null: false
      t.string :carrier, null: false
      t.string :service, null: false
      t.string :label
      t.decimal :markup_flat, precision: 10, scale: 2
      t.decimal :markup_percent, precision: 8, scale: 2
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :spree_delivery_method_services, [:delivery_method_id, :carrier, :service],
              unique: true, name: 'idx_delivery_method_services_uniqueness'
  end
end
