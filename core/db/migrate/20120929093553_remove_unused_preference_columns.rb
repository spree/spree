class RemoveUnusedPreferenceColumns < ActiveRecord::Migration
  def change
    # Columns have already been removed if the application was upgraded from an older version, but must be removed from new apps.
    remove_column :spree_preferences, :name       if ActiveRecord::Base.connection.column_exists?(:spree_preferences, :name)
    remove_column :spree_preferences, :owner_id   if ActiveRecord::Base.connection.column_exists?(:spree_preferences, :owner_id)
    remove_column :spree_preferences, :owner_type if ActiveRecord::Base.connection.column_exists?(:spree_preferences, :owner_type)
  end
end
