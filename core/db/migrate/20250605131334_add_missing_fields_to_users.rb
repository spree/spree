# this fields were not present when someone used a custom user class
# so we need to ensure this is setup properly
class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    users_table = Spree.user_class.table_name
    add_column users_table, :login, :string, if_not_exists: true

    json_type = if respond_to?(:jsonb)
      :jsonb
    else
      :json
    end

    add_column users_table, :public_metadata, json_type, if_not_exists: true
    add_column users_table, :private_metadata, json_type, if_not_exists: true

    add_reference users_table, :bill_address, if_not_exists: true
    add_reference users_table, :ship_address, if_not_exists: true

    admin_users_table = Spree.admin_user_class.table_name
    add_column admin_users_table, :login, :string, if_not_exists: true
    add_column admin_users_table, :public_metadata, json_type, if_not_exists: true
    add_column admin_users_table, :private_metadata, json_type, if_not_exists: true
  end
end
