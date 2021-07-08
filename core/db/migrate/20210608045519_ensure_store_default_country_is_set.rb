class EnsureStoreDefaultCountryIsSet < ActiveRecord::Migration[5.2]
  def change
    Spree::Store.find_each(&:save)
  end
end
