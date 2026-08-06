class RenameReturnAuthorizationReasonsToReturnReasons < ActiveRecord::Migration[8.1]
  def up
    # Each step is guarded so a re-run finishes what an interrupted one left
    # behind. This migration is copied into the host app, where it picks up a
    # fresh timestamp every time `spree:install:migrations` runs — so "already
    # partly applied" is a state it genuinely has to survive.
    if table_exists?(:spree_return_authorization_reasons)
      rename_table :spree_return_authorization_reasons, :spree_return_reasons
    end

    # Claim reasons are a separate vocabulary from return reasons — "arrived
    # damaged" and "never arrived" are not answers to "why are you sending
    # this back" (docs/plans/decisions.md 2026-08-05). Claims already carry a
    # generic reason_id; it now points here instead of at return reasons.
    # Checked explicitly rather than with `if_not_exists: true`: that option
    # skips the CREATE TABLE but still emits the index statements the block
    # declares, which then fail against a table that lacks those columns.
    unless table_exists?(:spree_claim_reasons)
      create_table :spree_claim_reasons do |t|
        t.string :name, null: false
        t.references :store, null: false
        t.boolean :active, null: false, default: true
        if t.respond_to?(:jsonb)
          t.jsonb :metadata
        else
          t.json :metadata
        end
        t.timestamps
      end
    end

    # An interrupted earlier run can leave the table behind in its pre-6.0
    # shape, so bring it up to the definition above.
    add_reference :spree_claim_reasons, :store unless column_exists?(:spree_claim_reasons, :store_id)

    unless column_exists?(:spree_claim_reasons, :metadata)
      add_column :spree_claim_reasons, :metadata, connection.adapter_name.match?(/postg/i) ? :jsonb : :json
    end

    # Store-owned like every other reason vocabulary, so two stores can each
    # have their own "Damaged" without colliding. Refund reasons join them:
    # all three answer "why", differ only in which record they explain, and a
    # single-store install can't tell the difference.
    add_reference :spree_return_reasons, :store unless column_exists?(:spree_return_reasons, :store_id)
    add_reference :spree_refund_reasons, :store unless column_exists?(:spree_refund_reasons, :store_id)

    # Backfilled here, then enforced NOT NULL in the same migration.
    #
    # The gap between the two matters: a unique (store_id, name) index does
    # NOT prevent duplicate names while store_id is NULL, because SQL treats
    # NULLs as distinct. Leaving rows unowned until a separate task ran would
    # let duplicates in through an index that looks like it forbids them, and
    # would hide every legacy reason from the store-scoped lookups that read
    # them.
    #
    # Read through SQL rather than Spree::Store: a migration that loads a model
    # breaks the moment that model's columns move ahead of this point in the
    # migration history.
    default_store_id = select_value(
      'SELECT id FROM spree_stores ORDER BY "default" DESC, id ASC LIMIT 1'
    )

    if default_store_id.present?
      execute("UPDATE spree_return_reasons SET store_id = #{default_store_id.to_i} WHERE store_id IS NULL")
      execute("UPDATE spree_refund_reasons SET store_id = #{default_store_id.to_i} WHERE store_id IS NULL")
    end

    # Enforce once nothing is left unowned — true on a fresh install (empty
    # tables) and after the backfill above. Rows that are still orphaned skip
    # the constraint rather than failing the migration;
    # spree:upgrade:backfill_reason_store_ids is the recovery path.
    %w[spree_return_reasons spree_refund_reasons spree_claim_reasons].each do |table|
      next if select_value("SELECT COUNT(*) FROM #{table} WHERE store_id IS NULL").to_i.positive?

      change_column_null table.to_sym, :store_id, false
    end

    # Reasons are no longer lockable. Nothing in core seeds an immutable one,
    # and `dependent: :restrict_with_error` already stops a reason that is in
    # use from being deleted — which is the protection that actually mattered.
    remove_column :spree_return_reasons, :mutable, if_exists: true
    remove_column :spree_refund_reasons, :mutable, if_exists: true
    remove_column :spree_claim_reasons, :mutable, if_exists: true

    remove_index :spree_return_reasons, :name, if_exists: true
    remove_index :spree_refund_reasons, :name, if_exists: true
    remove_index :spree_claim_reasons, :name, if_exists: true
    add_index :spree_return_reasons, [:store_id, :name], unique: true, if_not_exists: true
    add_index :spree_refund_reasons, [:store_id, :name], unique: true, if_not_exists: true
    add_index :spree_claim_reasons, [:store_id, :name], unique: true, if_not_exists: true
  end

  def down
    add_column :spree_return_reasons, :mutable, :boolean, default: true, if_not_exists: true
    add_column :spree_refund_reasons, :mutable, :boolean, default: true, if_not_exists: true

    remove_index :spree_return_reasons, [:store_id, :name], if_exists: true
    remove_index :spree_refund_reasons, [:store_id, :name], if_exists: true
    add_index :spree_return_reasons, :name, unique: true, if_not_exists: true
    add_index :spree_refund_reasons, :name, unique: true, if_not_exists: true

    remove_reference :spree_return_reasons, :store
    remove_reference :spree_refund_reasons, :store

    drop_table :spree_claim_reasons

    rename_table :spree_return_reasons, :spree_return_authorization_reasons
  end
end
