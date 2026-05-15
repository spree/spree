class AddStoreIdToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    add_reference :spree_newsletter_subscribers, :store

    if defined?(SpreeMultiTenant)
      Spree::Tenant.find_each do |tenant|
        SpreeMultiTenant.with_tenant(tenant) do
          Spree::NewsletterSubscriber.where(store_id: nil).update_all(store_id: Spree::Store.default.id)
        end
      end
    else
      Spree::NewsletterSubscriber.update_all(store_id: Spree::Store.default.id)
    end

    change_column_null :spree_newsletter_subscribers, :store_id, false

    remove_index :spree_newsletter_subscribers, :email, unique: true, if_exists: true
    add_index :spree_newsletter_subscribers, [:email, :store_id], unique: true, if_not_exists: true
  end

  def down
    remove_index :spree_newsletter_subscribers, [:email, :store_id], if_exists: true
    add_index :spree_newsletter_subscribers, :email, unique: true, if_not_exists: true
    remove_reference :spree_newsletter_subscribers, :store
  end
end
