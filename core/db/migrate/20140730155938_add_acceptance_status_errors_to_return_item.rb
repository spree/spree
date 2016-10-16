class AddAcceptanceStatusErrorsToReturnItem < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_return_items, :acceptance_status_errors, :text
  end
end
