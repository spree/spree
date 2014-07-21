class AddConsignmentsToOrders < ActiveRecord::Migration
  def change
    create_table :spree_consignments do |t|
      t.string   "number",                 limit: 32
      t.integer  "order_id"
      t.decimal  "item_total",                        precision: 10, scale: 2, default: 0.0,     null: false
      t.decimal  "total",                             precision: 10, scale: 2, default: 0.0,     null: false
      t.decimal  "adjustment_total",                  precision: 10, scale: 2, default: 0.0,     null: false
      t.datetime "completed_at"
      t.integer  "ship_address_id"
      t.integer  "shipping_method_id"
      t.string   "shipment_state"
      t.text     "special_instructions"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.decimal  "shipment_total",                    precision: 10, scale: 2, default: 0.0,     null: false
      t.decimal  "additional_tax_total",              precision: 10, scale: 2, default: 0.0
      t.decimal  "promo_total",                       precision: 10, scale: 2, default: 0.0
      t.decimal  "included_tax_total",                precision: 10, scale: 2, default: 0.0,     null: false
      t.integer  "item_count",                                                 default: 0
    end
  end
end
