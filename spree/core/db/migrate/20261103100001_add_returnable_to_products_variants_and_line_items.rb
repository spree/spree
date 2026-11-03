class AddReturnableToProductsVariantsAndLineItems < ActiveRecord::Migration[8.1]
  # Whether goods may come back through the customer's self-service returns.
  # A variant's nil defers to its product; a line item freezes the answer when
  # the order is placed, so later catalogue edits cannot strip a right already
  # sold (docs/plans/6.1-returns-portal.md).
  def change
    add_column :spree_products, :returnable, :boolean, default: true, null: false
    add_column :spree_variants, :returnable, :boolean
    add_column :spree_line_items, :returnable, :boolean, default: true, null: false
  end
end
