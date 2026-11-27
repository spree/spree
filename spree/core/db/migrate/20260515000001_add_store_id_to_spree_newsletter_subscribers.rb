class AddStoreIdToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    add_reference :spree_newsletter_subscribers, :store

    # For spree_multi_tenant we need handle the backfill and indices there
    return if defined?(SpreeMultiTenant)

    # Read without the models: Spree::Store expects its columns (preferences,
    # metadata) in the format later migrations convert them to, so loading a
    # store here crashes on a database upgraded from an earlier release.
    default_store_id = find_default_store_id
    if default_store_id.present?
      subscribers = Arel::Table.new(:spree_newsletter_subscribers)
      connection.update(Arel::UpdateManager.new.table(subscribers).set([[subscribers[:store_id], default_store_id]]))
    end

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

  private

  # Picks the store Spree::Store.default picked before this backfill stopped
  # loading the model: the oldest non-deleted store flagged as default (the
  # model's default scope orders by created_at). An imported database can hold
  # more than one default, and LIMIT 1 without an ORDER BY leaves the choice to
  # the database. Ordering by id as well keeps the pick stable when two stores
  # share a created_at.
  def find_default_store_id
    stores = Arel::Table.new(:spree_stores)
    connection.select_value(
      stores.project(stores[:id]).
        where(stores[:deleted_at].eq(nil).and(stores[:default].eq(true))).
        order(stores[:created_at].asc, stores[:id].asc).
        take(1)
    )
  end
end
