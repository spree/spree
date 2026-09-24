class AddCostSourceToSpreeFulfillments < ActiveRecord::Migration[8.1]
  def change
    # Who set the delivery cost. NULL means the selected delivery rate did, and
    # a re-quote may restate it; 'manual' means staff did, and nothing does.
    add_column :spree_fulfillments, :cost_source, :string
  end
end
