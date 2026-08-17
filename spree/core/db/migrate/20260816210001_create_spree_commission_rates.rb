class CreateSpreeCommissionRates < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_spree_commission_rates_on_store_id_and_code'.freeze
  RULE_INDEX_NAME = 'index_commission_rules_on_rate_and_type'.freeze
  RULE_PRODUCT_INDEX_NAME = 'index_commission_rule_products_on_rule_and_product'.freeze
  RATE_VALUE_INDEX_NAME = 'index_commission_rate_values_on_rate_and_currency'.freeze

  def change
    create_table :spree_commission_rates do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :code
      t.boolean :enabled, null: false, default: true
      # Resolution order: the list is walked top-down and the first matching
      # rate wins, so what an operator sees in the table IS the precedence.
      # Seeds arrive product-before-category-before-seller, which is the
      # conventional ladder; reordering is dragging a row.
      t.integer :position, null: false, default: 0

      t.string :kind, null: false # percentage | fixed
      # A percentage. Every *amount* a rate states — a flat fee, and a
      # percentage's floor and cap alike — lives in
      # spree_commission_rate_values, one row per currency, since "2" means
      # nothing without saying 2 of what.
      t.decimal :value, precision: 10, scale: 5, null: false, default: 0

      # Commission base: net (ex-VAT) item price by default, which is the EU
      # rule — the fee is a separate supply from the consumer's item sale.
      t.boolean :tax_inclusive, null: false, default: false
      # Also commission the seller order's delivery revenue.
      t.boolean :include_shipping, null: false, default: false

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

    # What a rate charges, and the bounds it charges within, in one currency.
    # Every amount a rate states lives here: a marketplace writes each one
    # deliberately rather than having a figure converted on its behalf, since
    # a converted number would drift daily against a fee a seller has agreed.
    #
    # A flat fee uses +amount+; a percentage leaves it at zero and may state a
    # floor and a cap instead, which is why only +amount+ carries a default.
    create_table :spree_commission_rate_values do |t|
      t.references :commission_rate, null: false
      t.string :currency, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :min_amount, precision: 10, scale: 2
      t.decimal :max_amount, precision: 10, scale: 2

      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_commission_rate_values, :deleted_at
    add_rate_value_uniqueness_index

    create_table :spree_commission_rules do |t|
      t.references :commission_rate, null: false
      # The rule kind, as a class name. Typed rather than a subject reference
      # so a rule can carry its own configuration — a value band or a date
      # window has nothing to point at.
      t.string :type, null: false

      if t.respond_to?(:jsonb)
        t.jsonb :preferences
      else
        t.json :preferences
      end

      t.timestamps
      # Rules are retired with their rate, and separately as an operator edits
      # a rate's conditions. Kept rather than deleted so a commission line
      # stays explainable: "why was this charged" is answered by the rule that
      # matched, which must still be readable afterwards.
      t.datetime :deleted_at
    end

    add_index :spree_commission_rules, :deleted_at
    # One rule of each kind per rate: a second would repeat the first or
    # contradict it, and under AND semantics contradiction means the rate
    # silently never applies. Live rows only, or replacing a rule would
    # collide with the retired one it supersedes.
    add_rule_uniqueness_index

    # Catalog-scale references get a table of their own — a marketplace naming
    # a thousand products should not put a thousand ids in a JSON column.
    create_table :spree_commission_rule_products do |t|
      t.references :commission_rule, null: false
      t.references :product, null: false

      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_commission_rule_products, :deleted_at
    # Unique among live rows only: a rule that named a product, dropped it and
    # named it again keeps the retired row beside the live one, but must never
    # hold the same product twice at once.
    add_rule_product_uniqueness_index
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
  # One amount per currency per rate, among live rows.
  def add_rate_value_uniqueness_index
    if mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_commission_rate_values
            ADD COLUMN currency_key VARCHAR(255)
            AS (IF(deleted_at IS NULL, currency, NULL)) STORED
          SQL
          add_index :spree_commission_rate_values, [:commission_rate_id, :currency_key],
                    unique: true, name: RATE_VALUE_INDEX_NAME
        end

        dir.down do
          remove_index :spree_commission_rate_values, name: RATE_VALUE_INDEX_NAME
          remove_column :spree_commission_rate_values, :currency_key
        end
      end
    else
      add_index :spree_commission_rate_values, [:commission_rate_id, :currency],
                unique: true, where: 'deleted_at IS NULL', name: RATE_VALUE_INDEX_NAME
    end
  end

  def add_rule_product_uniqueness_index
    if mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_commission_rule_products
            ADD COLUMN product_key BIGINT
            AS (IF(deleted_at IS NULL, product_id, NULL)) STORED
          SQL
          add_index :spree_commission_rule_products, [:commission_rule_id, :product_key],
                    unique: true, name: RULE_PRODUCT_INDEX_NAME
        end

        dir.down do
          remove_index :spree_commission_rule_products, name: RULE_PRODUCT_INDEX_NAME
          remove_column :spree_commission_rule_products, :product_key
        end
      end
    else
      add_index :spree_commission_rule_products, [:commission_rule_id, :product_id],
                unique: true, where: 'deleted_at IS NULL', name: RULE_PRODUCT_INDEX_NAME
    end
  end

  # Same per-adapter split as the rate's code index below, and for the same
  # reason: only PostgreSQL and SQLite have partial indexes.
  def add_rule_uniqueness_index
    if mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_commission_rules
            ADD COLUMN type_key VARCHAR(255)
            AS (IF(deleted_at IS NULL, type, NULL)) STORED
          SQL
          add_index :spree_commission_rules, [:commission_rate_id, :type_key],
                    unique: true, name: RULE_INDEX_NAME
        end

        dir.down do
          remove_index :spree_commission_rules, name: RULE_INDEX_NAME
          remove_column :spree_commission_rules, :type_key
        end
      end
    else
      add_index :spree_commission_rules, [:commission_rate_id, :type],
                unique: true, where: 'deleted_at IS NULL', name: RULE_INDEX_NAME
    end
  end

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
