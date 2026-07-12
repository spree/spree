class AddPreferencesToSpreeExports < ActiveRecord::Migration[7.2]
  def change
    # Same serialized preferences store spree_imports already has — first
    # consumer is the `results_url` the export-done email links back to.
    add_column :spree_exports, :preferences, :text
  end
end
