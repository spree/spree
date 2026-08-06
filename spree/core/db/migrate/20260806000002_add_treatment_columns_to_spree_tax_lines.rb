class AddTreatmentColumnsToSpreeTaxLines < ActiveRecord::Migration[8.1]
  def change
    # The cause of the treatment, not just its amount: zero-tax lines land in
    # different boxes of a tax return depending on why they are zero, and
    # e-invoicing integrations derive the invoice category and exemption codes
    # European mandates require from this reason plus the order's own facts.
    add_column :spree_tax_lines, :taxability_reason, :string

    # The taxing jurisdiction of the line. Not derivable from the shipping
    # address: origin-taxed sales (below-threshold digital supplies, US states
    # that source to the seller) tax somewhere else entirely, and the EU
    # one-stop-shop return is filed per destination country.
    add_column :spree_tax_lines, :country_iso, :string
    add_column :spree_tax_lines, :state_code, :string

    add_index :spree_tax_lines, :taxability_reason
    add_index :spree_tax_lines, [:country_iso, :state_code]
  end
end
