# these fields were not present when someone used a custom user class
# so we need to ensure this is setup properly
class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    users_table = Spree.user_class.table_name
    admin_users_table = Spree.admin_user_class.table_name

    change_table users_table do |t|
      t.string :login unless column_exists?(users_table, :login)

      if t.respond_to? :jsonb
        t.jsonb :metadata unless column_exists?(users_table, :metadata)
      else
        t.json :metadata unless column_exists?(users_table, :metadata)
      end
    end

    add_reference users_table, :bill_address, if_not_exists: true
    add_reference users_table, :ship_address, if_not_exists: true

    change_table admin_users_table do |t|
      t.string :login unless column_exists?(admin_users_table, :login)

      if t.respond_to? :jsonb
        t.jsonb :metadata unless column_exists?(admin_users_table, :metadata)
      else
        t.json :metadata unless column_exists?(admin_users_table, :metadata)
      end
    end
  end
end
