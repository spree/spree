class CreateSpreeResourceUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_resource_users do |t|
      t.references :resource, null: false, polymorphic: true # Store, Vendor, etc
      t.references :user, null: false, polymorphic: true # Spree::User, Spree::AdminUser, etc
      t.references :invitation, null: true # Spree::Invitation, if the resource_user was created from an invitation

      t.timestamps
    end

    add_index :spree_resource_users, [:resource_id, :resource_type, :user_id, :user_type], unique: true

    # migrate existing admin users to resource_users
    unless Rails.env.test?
      Spree.admin_user_class.all.each do |admin_user|
        Spree::Store.all.each do |store|
          store.resource_users.find_or_create_by!(user: admin_user)
        end
      end
    end
  end
end
