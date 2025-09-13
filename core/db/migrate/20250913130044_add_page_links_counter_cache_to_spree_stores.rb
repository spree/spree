class AddPageLinksCounterCacheToSpreeStores < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_stores, :page_links_count, :integer, default: 0

    Spree::Store.find_each do |store|
      Spree::Store.reset_counters(store.id, :page_links)
    end
  end
end
