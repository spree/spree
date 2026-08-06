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
      t.timestamps
    end

    # Store-owned like every other reason vocabulary, so two stores can each
    # have their own "Damaged" without colliding. The uniqueness scope moves
    # with it: name is unique per store, not globally.
    add_reference :spree_return_reasons, :store

    remove_index :spree_return_reasons, :name
    add_index :spree_return_reasons, [:store_id, :name], unique: true
    add_index :spree_claim_reasons, [:store_id, :name], unique: true
  end
end
