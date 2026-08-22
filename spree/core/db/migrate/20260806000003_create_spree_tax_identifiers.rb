class CreateSpreeTaxIdentifiers < ActiveRecord::Migration[8.1]
  def change
    # The buyer's tax registration — a VAT number and its kind. Without it no
    # provider can apply EU B2B reverse charge, because Spree had nowhere to put
    # a customer's VAT number at all.
    #
    # No store_id: the row belongs to a customer, cart or order that already
    # carries the store, matching spree_tax_lines.
    create_table :spree_tax_identifiers do |t|
      # Whoever holds this registration. A customer, company or seller holds
      # one per kind — the durable profile value; a cart holds a checkout-time
      # override and an order the frozen completion snapshot.
      t.references :owner, polymorphic: true, null: false

      t.string :kind, null: false
      t.string :value, null: false

      # Written only by the validation service. A registry answers "valid now",
      # so the evidence captured at validation time is the only proof that will
      # ever exist for a past sale.
      t.string :validation_status
      t.datetime :validated_at
      if t.respond_to?(:jsonb)
        t.jsonb :validation_evidence
      else
        t.json :validation_evidence
      end

      # Which link of the resolution chain won — order-owned snapshots only.
      t.string :source

      t.timestamps
    end

    # One registration per kind per owner, which is what makes resolution
    # unambiguous. Cart and order owners hold a single row each through their
    # associations and are covered by the same rule.
    add_index :spree_tax_identifiers, [:owner_type, :owner_id, :kind],
              unique: true, name: 'index_spree_tax_identifiers_on_owner_and_kind'
  end
end
