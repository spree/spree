class AddSellerBusinessIdentityAndStockLocations < ActiveRecord::Migration[8.1]
  def change
    # Seller-owned stock. Nullable: an operator's own locations have no seller,
    # and that is the common case in a store that is not a marketplace.
    #
    # No uniqueness index on the name alongside it. Names are unique per owner
    # once a marketplace has sellers, but that stays a validation as it always
    # has been on this table — nothing resolves a location by name.
    add_reference :spree_stock_locations, :seller, null: true

    # The business behind the seller, as a commission invoice must address it.
    # Distinct from the trading name: "Sparks" sells, "Sparks Trading Ltd"
    # is invoiced.
    add_column :spree_sellers, :legal_name, :string
    add_column :spree_sellers, :registration_number, :string

    # A fifth owner for the tax registration (docs/plans/6.0-tax-provider.md
    # Phase 7). The seller's VAT number needs the validation verdict and the
    # retained evidence the model already carries: EU reverse charge on the
    # commission invoice has to stay defensible years after the registry that
    # answered has moved on.
    add_reference :spree_tax_identifiers, :seller, null: true
  end
end
