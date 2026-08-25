class CreateSpreeCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_companies do |t|
      t.references :store, null: false
      t.references :parent                   # self-referential tree, nil = root
      t.string :name, null: false
      # 'company' (legal entity) or 'division' (organizational unit). No DB
      # default per the string-column rule; the model normalizes a blank kind.
      t.string :kind, null: false
      # No external_id column — ERP/CRM identity lives on
      # Spree::ExternalReference. No tax_exempt boolean — exemption is a certificate scoped to a
      # jurisdiction, which a flag cannot express (docs/plans/decisions.md
      # 2026-08-07).
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    # The address book: rows a node owns outright, never shared with a
    # customer's own address book.
    create_table :spree_company_addresses do |t|
      t.references :company, null: false
      t.references :address, null: false
      t.string :label
      t.boolean :default_billing, null: false, default: false
      t.boolean :default_shipping, null: false, default: false
      t.timestamps
    end

    # Partial unique indexes: at most one default of each kind per node.
    # Supported on Postgres and SQLite; MySQL ignores +where:+, so the model
    # demotes prior defaults before save (same shape as Channel#default).
    unless ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      add_index :spree_company_addresses, :company_id, unique: true,
                where: 'default_billing = TRUE',
                name: 'idx_company_addresses_default_billing'
      add_index :spree_company_addresses, :company_id, unique: true,
                where: 'default_shipping = TRUE',
                name: 'idx_company_addresses_default_shipping'
    end

    # Membership gives a customer standing over the node and its subtree.
    # Always customer-backed — the not-yet-registered case is an invitation.
    create_table :spree_company_memberships do |t|
      t.references :company, null: false
      t.references :customer, null: false
      t.string :role                         # cosmetic label, no behavior in OSS
      t.timestamps
    end

    add_index :spree_company_memberships, [:company_id, :customer_id], unique: true,
              name: 'idx_company_memberships_on_company_and_customer'

    create_table :spree_company_invitations do |t|
      t.references :company, null: false
      t.references :inviter                  # customer who invited; nil = staff
      t.references :customer                 # bound at acceptance
      t.string :email, null: false
      t.string :token, null: false           # plaintext, like the staff invitation token
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_company_invitations, :token, unique: true
    add_index :spree_company_invitations, [:company_id, :email]

    # Both sides: exemption has to resolve while the buyer is still in
    # checkout, and completion copies the node onto the order.
    add_reference :spree_carts, :company
    add_reference :spree_orders, :company
  end
end
