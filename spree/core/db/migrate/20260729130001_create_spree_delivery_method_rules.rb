class CreateSpreeDeliveryMethodRules < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_delivery_method_rules do |t|
      t.string :type, null: false
      t.references :delivery_method, null: false
      t.boolean :active
      if t.respond_to?(:jsonb)
        t.jsonb :preferences
      else
        t.json :preferences
      end

      t.timestamps
    end

    add_index :spree_delivery_method_rules, [:delivery_method_id, :type], unique: true,
              name: 'idx_delivery_method_rules_uniqueness'
  end
end
