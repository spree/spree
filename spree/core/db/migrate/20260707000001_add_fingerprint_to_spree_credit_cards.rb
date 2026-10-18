class AddFingerprintToSpreeCreditCards < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'index_spree_credit_cards_unique_fingerprint'.freeze

  def up
    add_column :spree_credit_cards, :fingerprint, :string

    # Prevent duplicate saved cards (same gateway fingerprint + expiry) per user
    # and payment method at the database level, backing the application-level
    # check against concurrent writes. Only active, fingerprinted cards are
    # constrained, so legacy/non-gateway cards (NULL fingerprint) and
    # soft-deleted rows are left untouched.
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      # MySQL has no partial indexes, but treats NULL as distinct in unique
      # indexes, so NULL fingerprints are naturally allowed. The default value of
      # deleted_at in the virtual column enables enforcing uniqueness of non-deleted
      # values and keeps soft-deleted rows from colliding with active ones.
      add_column :spree_credit_cards, :deleted_at_with_default, :virtual, type: :datetime, as: "IFNULL(deleted_at, '1970-01-01 00:00:00')", stored: false
      add_index :spree_credit_cards, [:user_id, :payment_method_id, :fingerprint, :month, :year, :deleted_at_with_default],
                unique: true,
                name: INDEX_NAME
    else
      add_index :spree_credit_cards, [:user_id, :payment_method_id, :fingerprint, :month, :year],
                unique: true,
                where: 'fingerprint IS NOT NULL AND deleted_at IS NULL',
                name: INDEX_NAME
    end
  end

  def down
    remove_index :spree_credit_cards, name: INDEX_NAME
    remove_column :spree_credit_cards, :fingerprint
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      remove_column :spree_credit_cards, :deleted_at_with_default
    end
  end
end
