class AddSellerToSpreeDeliveryMethods < ActiveRecord::Migration[8.1]
  def change
    # Null means the operator's own method — the marketplace's, and the only
    # kind that existed before this column.
    add_reference :spree_delivery_methods, :seller, index: true

    # Whether the operator lets sellers' packages be quoted by this method.
    # Default false: sharing shipping is a decision, not a starting point.
    add_column :spree_delivery_methods, :available_to_sellers, :boolean, null: false, default: false
  end
end
