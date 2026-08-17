class CreateSpreeCommissionRates < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_spree_commission_rates_on_store_id_and_code'.freeze

  def change
    create_table :spree_commission_rates do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :code
      t.boolean :enabled, null: false, default: true
      # Resolution order: the list is walked top-down and the first matching
      # rate wins, so what an operator sees in the table IS the precedence.
      # Seeds arrive product-before-category-before-vendor, which is the
      # conventional ladder; reordering is dragging a row.
      t.integer :position, null: false, default: 0

      t.string :kind, null: false # percentage | fixed
      t.decimal :value, precision: 10, scale: 5, null: false, default: 0
      # Required for a fixed rate (a flat "2" means nothing without one),
      # ignored for a percentage.
      t.string :currency

      # Commission base: net (ex-VAT) item price by default, which is the EU
      # rule — the fee is a separate supply from the consumer's item sale.
      t.boolean :tax_inclusive, null: false, default: false
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

    add_code_uniqueness_index
    add_index :spree_commission_rates, [:store_id, :enabled, :position]
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

  private

  # A code is unique per store among the rates that are still there. Rates are
  # paranoid, so a store that retires one must be able to reuse its code.
  #
  # Written per adapter because only PostgreSQL and SQLite have partial
  # indexes. MySQL and MariaDB instead index a stored generated column holding
  # the code only while the row is live, so a retired rate drops out of the
  # index altogether — NULLs compare distinct there, which also lets a store
  # retire and reuse the same code repeatedly.
  #
  # Verified against MySQL 8 and MariaDB 11: the two disagree sharply about
  # what a generated column may contain. A DATETIME sentinel (`COALESCE(
  # deleted_at, CAST(...))`) is MySQL-only, `UNIX_TIMESTAMP` is MariaDB-only,
  # and a functional index on COALESCE — the older precedent in this tree — is
  # MySQL-only too. This expression is the one both accept.
  def add_code_uniqueness_index
    if mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_commission_rates
            ADD COLUMN code_key VARCHAR(255)
            AS (IF(deleted_at IS NULL, code, NULL)) STORED
          SQL
          add_index :spree_commission_rates, [:store_id, :code_key], unique: true, name: INDEX_NAME
        end

        dir.down do
          remove_index :spree_commission_rates, name: INDEX_NAME
          remove_column :spree_commission_rates, :code_key
        end
      end
    else
      add_index :spree_commission_rates, [:store_id, :code],
                unique: true, where: 'deleted_at IS NULL', name: INDEX_NAME
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name.match?(/mysql|trilogy/i)
  end
end
