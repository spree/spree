class AddStoreIdToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    add_reference :spree_newsletter_subscribers, :store

    # For spree_multi_tenant we need handle the backfill and indices there
    return if defined?(SpreeMultiTenant)

    default_store = Spree::Store.default
    Spree::NewsletterSubscriber.update_all(store_id: default_store.id) if default_store&.persisted?

    change_column_null :spree_newsletter_subscribers, :store_id, false

    remove_index :spree_newsletter_subscribers, :email, unique: true, if_exists: true
    add_index :spree_newsletter_subscribers, [:email, :store_id], unique: true, if_not_exists: true
  end

  def down
    unless defined?(SpreeMultiTenant)
      remove_index :spree_newsletter_subscribers, [:email, :store_id], if_exists: true
      add_index :spree_newsletter_subscribers, :email, unique: true, if_not_exists: true
    end

    remove_reference :spree_newsletter_subscribers, :store
  end
end
