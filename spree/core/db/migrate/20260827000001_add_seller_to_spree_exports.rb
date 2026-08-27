class AddSellerToSpreeExports < ActiveRecord::Migration[8.1]
  def change
    add_reference :spree_exports, :seller, null: true, index: true
  end
end
