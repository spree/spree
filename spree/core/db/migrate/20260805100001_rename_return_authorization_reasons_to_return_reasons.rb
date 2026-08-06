class RenameReturnAuthorizationReasonsToReturnReasons < ActiveRecord::Migration[8.1]
  def change
    rename_table :spree_return_authorization_reasons, :spree_return_reasons

    # Claim reasons are a separate vocabulary from return reasons — "arrived
    # damaged" and "never arrived" are not answers to "why are you sending
    # this back" (docs/plans/decisions.md 2026-08-05). Claims already carry a
    # generic reason_id; it now points here instead of at return reasons.
    create_table :spree_claim_reasons do |t|
      t.string :name, null: false
      t.references :store, null: false
      t.boolean :active, null: false, default: true
      t.boolean :mutable, null: false, default: true
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    # Store-owned like every other reason vocabulary, so two stores can each
    # have their own "Damaged" without colliding. The uniqueness scope moves
    # with it: name is unique per store, not globally.
    #
    # Refund reasons join them: all three answer "why", differ only in which
    # record they explain, and a single-store install can't tell the
    # difference.
    #
    # Existing rows are backfilled by `spree:backfill_reason_store_ids`, not
    # here — data transformations belong in a rake task. That matters more
    # than usual for refund reasons: core looks three of them up by name, so
    # until the task runs those lookups see a null store_id and would mint a
    # duplicate per store.
    add_reference :spree_return_reasons, :store
    add_reference :spree_refund_reasons, :store

    remove_index :spree_return_reasons, :name
    remove_index :spree_refund_reasons, :name
    add_index :spree_return_reasons, [:store_id, :name], unique: true
    add_index :spree_refund_reasons, [:store_id, :name], unique: true
    add_index :spree_claim_reasons, [:store_id, :name], unique: true
  end
end
