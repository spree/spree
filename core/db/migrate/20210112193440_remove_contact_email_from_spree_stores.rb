class RemoveContactEmailFromSpreeStores < ActiveRecord::Migration[5.2]
  def change
    remove_column :spree_stores, :contact_email, :string
  end
end
