# this fields were not present when someone used a custom user class
# so we need to ensure this is setup properly
class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    users_table = Spree.user_class.table_name
    admin_users_table = Spree.admin_user_class.table_name

    change_table users_table do |t|
      add_column users_table, :login, :string, if_not_exists: true

      if t.respond_to? :jsonb
        add_column users_table, :public_metadata, :jsonb, if_not_exists: true
        add_column users_table, :private_metadata, :jsonb, if_not_exists: true
      else
        add_column users_table, :public_metadata, :json, if_not_exists: true
        add_column users_table, :private_metadata, :json, if_not_exists: true
      end

      add_reference users_table, :bill_address, if_not_exists: true
      add_reference users_table, :ship_address, if_not_exists: true
    end

    change_table admin_users_table do |t|
      add_column admin_users_table, :login, :string, if_not_exists: true

      if t.respond_to? :jsonb
        add_column admin_users_table, :public_metadata, :jsonb, if_not_exists: true
        add_column admin_users_table, :private_metadata, :jsonb, if_not_exists: true
      else
        add_column admin_users_table, :public_metadata, :json, if_not_exists: true
        add_column admin_users_table, :private_metadata, :json, if_not_exists: true
      end
    end
  end
end
