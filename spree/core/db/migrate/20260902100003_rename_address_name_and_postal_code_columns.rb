class RenameAddressNameAndPostalCodeColumns < ActiveRecord::Migration[8.1]
  # docs/plans/5.4-store-api-naming-standardization.md. The API has spoken
  # first_name / last_name / postal_code since 5.4, but Ransack filter keys and
  # validation error keys carry the column name, so both still leaked the old
  # ones. The two indexes are named after the columns rather than derived from
  # them, so they have to move by hand.
  def up
    rename_column :spree_addresses, :firstname, :first_name
    rename_column :spree_addresses, :lastname, :last_name
    rename_column :spree_addresses, :zipcode, :postal_code

    rename_index :spree_addresses, 'index_addresses_on_firstname', 'index_addresses_on_first_name'
    rename_index :spree_addresses, 'index_addresses_on_lastname', 'index_addresses_on_last_name'
  end

  def down
    rename_index :spree_addresses, 'index_addresses_on_first_name', 'index_addresses_on_firstname'
    rename_index :spree_addresses, 'index_addresses_on_last_name', 'index_addresses_on_lastname'

    rename_column :spree_addresses, :postal_code, :zipcode
    rename_column :spree_addresses, :last_name, :lastname
    rename_column :spree_addresses, :first_name, :firstname
  end
end
