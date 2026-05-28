class AddChannelToSpreeProductsStores < ActiveRecord::Migration[7.2]
  def up
    add_reference :spree_products_stores, :channel
    add_column    :spree_products_stores, :published_at,   :datetime
    add_column    :spree_products_stores, :unpublished_at, :datetime

    Spree::Store.includes(:default_channel).find_each do |store|
      Spree::ProductPublication.where(store_id: store.id).update_all(channel_id: store.default_channel_id)
    end
  end

  def down
    remove_column :spree_products_stores, :unpublished_at
    remove_column :spree_products_stores, :published_at
    remove_reference :spree_products_stores, :channel
  end
end
