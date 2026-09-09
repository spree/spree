class CreateSpreePriceAdjustmentTiers < ActiveRecord::Migration[8.1]
  def change
    # The higher bands of a list's percentage adjustment. The list's own
    # `price_adjustment_percentage` column stays its quantity-1 value, so a
    # list with no tiers behaves exactly as it does today
    # (docs/plans/6.0-volume-pricing.md).
    create_table :spree_price_adjustment_tiers do |t|
      t.references :price_list, null: false, index: false
      t.integer :min_quantity, null: false, default: 1
      t.decimal :percentage, precision: 6, scale: 3, null: false, default: 0

      t.timestamps
    end

    add_index :spree_price_adjustment_tiers, [:price_list_id, :min_quantity],
              name: 'index_spree_price_adjustment_tiers_on_list_and_quantity',
              unique: true
  end
end
