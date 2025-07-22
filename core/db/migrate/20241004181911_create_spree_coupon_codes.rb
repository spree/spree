class CreateSpreeCouponCodes < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:spree_coupon_codes)

    create_table :spree_coupon_codes do |t|
      t.string :code, index: { unique: true }
      t.references :promotion, index: true
      t.references :order, index: true
      t.integer :state, default: 0, null: false, index: true
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
