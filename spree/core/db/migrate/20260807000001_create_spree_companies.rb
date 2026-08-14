class CreateSpreeCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_companies do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :external_id                  # ERP/CRM reference
      # No tax_exempt boolean — exemption is a certificate scoped to a
      # jurisdiction, which a flag cannot express (docs/plans/decisions.md
      # 2026-08-07).
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_companies, [:store_id, :external_id], unique: true,
              where: 'external_id IS NOT NULL', name: 'idx_companies_external_id'

    # No store_id on the children: they reach the store through the company,
    # matching spree_return_line_items.
    create_table :spree_company_locations do |t|
      t.references :company, null: false
      t.references :billing_address
      t.references :shipping_address
      t.string :name, null: false
      t.string :external_id
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    create_table :spree_company_contacts do |t|
      t.references :company_location, null: false
      t.references :customer, null: false
      t.string :role, null: false, default: 'buyer'   # no behavior attached in 6.0
      t.timestamps
    end

    add_index :spree_company_contacts, [:company_location_id, :customer_id], unique: true,
              name: 'idx_company_contacts_on_location_and_customer'

    # Both sides: exemption has to resolve while the buyer is still in
    # checkout, and completion copies the branch onto the order.
    add_reference :spree_carts, :company_location
    add_reference :spree_orders, :company_location
  end
end
