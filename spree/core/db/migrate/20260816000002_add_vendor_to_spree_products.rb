class AddVendorToSpreeProducts < ActiveRecord::Migration[8.1]
  # Which seller owns this product. Nil is the operator's own first-party
  # catalog, which is every product on a store that sells nothing but its own.
  #
  # Replaces the guarded Spree::VendorConcern hook the Enterprise module used
  # to fill: the marketplace is core now, so the column is too.
  def change
    add_reference :spree_products, :vendor, index: true
  end
end
