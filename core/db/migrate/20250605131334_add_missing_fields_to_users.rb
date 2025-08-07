# this fields were not present when someone used a custom user class
# so we need to ensure this is setup properly
class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    users_table = Spree.user_class.table_name
    admin_users_table = Spree.admin_user_class.table_name

    change_table users_table do |t|
      t.string :login, if_not_exists: true

      if t.respond_to? :jsonb
        t.jsonb :public_metadata, if_not_exists: true
        t.jsonb :private_metadata, if_not_exists: true
      else
        t.json :public_metadata, if_not_exists: true
        t.json :private_metadata, if_not_exists: true
      end

      t.references :bill_address, if_not_exists: true
      t.references :ship_address, if_not_exists: true
    end

    change_table admin_users_table do |t|
      t.string :login, if_not_exists: true

      if t.respond_to? :jsonb
        t.jsonb :public_metadata, if_not_exists: true
        t.jsonb :private_metadata, if_not_exists: true
      else
        t.json :public_metadata, if_not_exists: true
        t.json :private_metadata, if_not_exists: true
      end
    end
  end
end
