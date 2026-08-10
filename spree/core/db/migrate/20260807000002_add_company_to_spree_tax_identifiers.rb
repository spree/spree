class AddCompanyToSpreeTaxIdentifiers < ActiveRecord::Migration[8.1]
  def change
    # A fourth owner, still exactly one per row: the registration of the entity
    # the invoice is addressed to, which outranks the buyer's own.
    add_reference :spree_tax_identifiers, :company, null: true

    add_index :spree_tax_identifiers, [:company_id, :kind], unique: true
  end
end
