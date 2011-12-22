class AddCompanyToAddresses < ActiveRecord::Migration
  def change
    add_column :spree_addresses, :company, :string
  end
end
