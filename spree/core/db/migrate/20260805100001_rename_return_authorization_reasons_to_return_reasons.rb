class RenameReturnAuthorizationReasonsToReturnReasons < ActiveRecord::Migration[8.1]
  def change
    rename_table :spree_return_authorization_reasons, :spree_return_reasons

    # Claim reasons are a separate vocabulary from return reasons — "arrived
    # damaged" and "never arrived" are not answers to "why are you sending
    # this back" (docs/plans/decisions.md 2026-08-05). Claims already carry a
    # generic reason_id; it now points here instead of at return reasons.
    create_table :spree_claim_reasons do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.boolean :mutable, null: false, default: true
      t.timestamps
    end

    add_index :spree_claim_reasons, :name, unique: true
  end
end
