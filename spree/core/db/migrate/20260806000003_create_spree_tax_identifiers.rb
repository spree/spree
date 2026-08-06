class CreateSpreeTaxIdentifiers < ActiveRecord::Migration[8.1]
  def change
    # The buyer's tax registration — a VAT number and its kind. Without it no
    # provider can apply EU B2B reverse charge, because Spree had nowhere to put
    # a customer's VAT number at all.
    #
    # No store_id: the row belongs to a customer, cart or order that already
    # carries the store, matching spree_tax_lines.
    create_table :spree_tax_identifiers do |t|
      # Owner — exactly one (enforced at model level). The customer row is the
      # durable profile value, the cart row a checkout-time override, the order
      # row a frozen completion snapshot.
      t.references :customer, null: true
      t.references :cart, null: true
      t.references :order, null: true

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

    add_index :spree_tax_identifiers, [:customer_id, :kind]
  end
end
