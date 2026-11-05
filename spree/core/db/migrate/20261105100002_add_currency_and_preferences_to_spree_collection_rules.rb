# `currency` names the currency a price or sale rule evaluates in (the
# store's default when blank); `preferences` holds per-type options such as
# a category rule's `include_descendants`.
class AddCurrencyAndPreferencesToSpreeCollectionRules < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_collection_rules do |t|
      t.string :currency
      if t.respond_to?(:jsonb)
        t.jsonb :preferences
      else
        t.json :preferences
      end
    end
  end
end
