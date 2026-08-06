class CreateSpreeDeliveryMethodRuleProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_delivery_method_rule_products do |t|
      t.references :delivery_method_rule, null: false, index: false
      t.references :product, null: false

      t.timestamps
    end

    add_index :spree_delivery_method_rule_products, [:delivery_method_rule_id, :product_id],
              unique: true, name: 'idx_delivery_method_rule_products_uniqueness'

    # Never writable through any API or UI, so there is no data to carry over —
    # per-product exclusions live on ExcludedProductsRule now
    # (docs/plans/6.0-delivery-method-rules.md, decision 2026-08-06).
    if connection.adapter_name.downcase.include?('postgresql')
      remove_column :spree_products, :excluded_delivery_method_ids, :jsonb
    else
      remove_column :spree_products, :excluded_delivery_method_ids, :json
    end
  end
end
