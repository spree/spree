# This migration comes from spree (originally 20210930155649)
class AddSettingsToSpreeStores < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_stores do |t|
      if t.respond_to? :jsonb
        add_column :spree_stores, :settings, :jsonb
      else
        add_column :spree_stores, :settings, :json
      end
    end
  end
end
