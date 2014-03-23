class RemoveValueTypeFromSpreePreferences < ActiveRecord::Migration
  def up
    remove_column :spree_preferences, :value_type
  end
  def down
    raise ActiveRecord::IrreversableMigration
  end
end
