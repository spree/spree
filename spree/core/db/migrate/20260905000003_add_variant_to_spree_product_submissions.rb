class AddVariantToSpreeProductSubmissions < ActiveRecord::Migration[8.1]
  def change
    # A submission is about a product OR about one seller's offer on a master
    # product. The row is otherwise identical — who submitted, who decided,
    # when, and what the seller was told — so it carries an optional variant
    # rather than being copied into a second table
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    add_reference :spree_product_submissions, :variant, null: true

    # The latest row for an offer is the live one, exactly as for a product.
    add_index :spree_product_submissions, [:variant_id, :created_at]
  end
end
