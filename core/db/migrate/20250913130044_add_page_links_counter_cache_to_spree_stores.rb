class AddPageLinksCounterCacheToSpreeStores < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stores, :page_links_count, :integer, default: 0, null: false

    Spree::Store.reset_column_information
    Spree::Store.find_each do |store|
      Spree::Store.reset_counters(store.id, :links)
    end
  end
end
