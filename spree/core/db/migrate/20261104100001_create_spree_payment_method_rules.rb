# Conditions that decide whether a payment method is offered at checkout.
# See docs/plans/6.1-payment-method-rules.md.
class CreateSpreePaymentMethodRules < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_payment_method_rules do |t|
      t.string :type, null: false
      t.references :payment_method, null: false
      t.boolean :active, null: false, default: true
      if t.respond_to?(:jsonb)
        t.jsonb :preferences
      else
        t.json :preferences
      end

      t.timestamps
    end

    add_index :spree_payment_method_rules, [:payment_method_id, :type], unique: true,
                                                                        name: 'idx_payment_method_rules_uniqueness'
  end
end
