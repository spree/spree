class AddFingerprintToSpreeCreditCards < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'index_spree_credit_cards_unique_fingerprint'.freeze
  GENERATED_COLUMN = 'deleted_at_not_null'.freeze

  def up
    add_column :spree_credit_cards, :fingerprint, :string

    # Prevent duplicate saved cards (same gateway fingerprint + expiry) per user
    # and payment method at the database level, backing the application-level
    # check against concurrent writes. Only active, fingerprinted cards are
    # constrained, so legacy/non-gateway cards (NULL fingerprint) and
    # soft-deleted rows are left untouched.
    connection = ActiveRecord::Base.connection

    if connection.adapter_name == 'Mysql2'
      # MySQL/MariaDB have no partial indexes, but treat NULL as distinct in
      # unique indexes, so NULL fingerprints are naturally allowed. Folding
      # deleted_at into a constant keeps soft-deleted rows from colliding with
      # active ones.
      if connection.mariadb?
        # MariaDB has no functional key parts, so index a persistent generated
        # column that carries the coalesced value.
        execute <<-SQL
          ALTER TABLE spree_credit_cards
          ADD COLUMN #{GENERATED_COLUMN} DATETIME(6) AS (COALESCE(deleted_at, DATE'1970-01-01')) PERSISTENT
        SQL
        execute <<-SQL
          CREATE UNIQUE INDEX #{INDEX_NAME}
          ON spree_credit_cards(user_id, payment_method_id, fingerprint, month, year, #{GENERATED_COLUMN})
        SQL
      else
        execute <<-SQL
          CREATE UNIQUE INDEX #{INDEX_NAME}
          ON spree_credit_cards(
            user_id,
            payment_method_id,
            fingerprint,
            month,
            year,
            (COALESCE(deleted_at, CAST('1970-01-01' AS DATETIME)))
          )
        SQL
      end
    else
      add_index :spree_credit_cards, [:user_id, :payment_method_id, :fingerprint, :month, :year],
                unique: true,
                where: 'fingerprint IS NOT NULL AND deleted_at IS NULL',
                name: INDEX_NAME
    end
  end

  def down
    remove_index :spree_credit_cards, name: INDEX_NAME, if_exists: true
    remove_column :spree_credit_cards, GENERATED_COLUMN if column_exists?(:spree_credit_cards, GENERATED_COLUMN)
    remove_column :spree_credit_cards, :fingerprint
  end
end
