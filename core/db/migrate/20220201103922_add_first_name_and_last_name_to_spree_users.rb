class AddFirstNameAndLastNameToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    if Spree.user_class.present?
      add_column :spree_users, :first_name, :string unless column_exists?(:spree_users, :first_name)
      add_column :spree_users, :last_name, :string unless column_exists?(:spree_users, :last_name)
    end
  end
end
