class CreateSpreeCommissionRates < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_commission_rates do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :code
      t.boolean :enabled, null: false, default: true
      # Walked DESC when resolving, first match wins. Operator-assignable, so
      # a marketplace reorders its own ladder instead of inheriting one.
      t.integer :priority, null: false, default: 0

      t.string :kind, null: false # percentage | fixed
      t.decimal :value, precision: 10, scale: 5, null: false, default: 0
      # Required for a fixed rate (a flat "2" means nothing without one),
      # ignored for a percentage.
      t.string :currency

      # Commission base: net (ex-VAT) item price by default, which is the EU
      # rule — the fee is a separate supply from the consumer's item sale.
      t.boolean :include_tax, null: false, default: false
      # Also commission the vendor order's delivery revenue.
      t.boolean :include_shipping, null: false, default: false

      t.decimal :min_amount, precision: 10, scale: 2
      t.decimal :max_amount, precision: 10, scale: 2

      # Overrides the tax provider's answer for VAT on the commission. Null
      # means ask the provider, which is what keeps the rate jurisdiction-correct.
      t.decimal :commission_tax_rate, precision: 8, scale: 5

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
      t.datetime :deleted_at
    end

    # Deleted rows are excluded, matching the model's own uniqueness check:
    # rates are paranoid, so without this a store could never reuse the code of
    # a rate it had retired.
    add_index :spree_commission_rates, [:store_id, :code], unique: true, where: 'deleted_at IS NULL'
    add_index :spree_commission_rates, [:store_id, :enabled, :priority]
    add_index :spree_commission_rates, :deleted_at

    create_table :spree_commission_rules do |t|
      t.references :commission_rate, null: false
      # Product | Category | Vendor. Null on every column means a global rule,
      # which is how a rate with no targeting matches everything.
      t.references :subject, polymorphic: true

      t.timestamps
    end

    add_index :spree_commission_rules,
              [:commission_rate_id, :subject_type, :subject_id],
              unique: true,
              name: 'index_commission_rules_on_rate_and_subject'
  end
end
