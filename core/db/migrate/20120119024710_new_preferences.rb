class NewPreferences < ActiveRecord::Migration

  class OldPrefs < ActiveRecord::Base
    self.table_name = "spree_preferences"
    belongs_to  :owner, :polymorphic => true
  end

  def up
    add_column :spree_preferences, :key, :string
    add_column :spree_preferences, :value_type, :string
    add_index :spree_preferences, :key, :unique => true

    # remove old constraints for migration
    change_column :spree_preferences, :name, :string, :null => true
    change_column :spree_preferences, :owner_id, :integer, :null => true
    change_column :spree_preferences, :owner_type, :string, :null => true
    change_column :spree_preferences, :group_id, :integer, :null => true
    change_column :spree_preferences, :group_type, :string, :null => true

    OldPrefs.all.each do |old_pref|
      begin
        begin
          owner = old_pref.owner
        rescue => e1
          # case:
          # AppConfiguration is no longer an sti derivative of Configuration
          owner_class = old_pref.owner_type.constantize
          owner = OldPrefs.connection.select_value("SELECT #{owner_class.inheritance_column} FROM #{owner_class.table_name} WHERE id = #{old_pref.owner_id}").constantize.new
        end

        unless old_pref.owner_type.nil?
        end

        unless old_pref.owner_type == "Spree::Activator" || old_pref.owner_type == "Spree::PromotionRule"
          say "Migrating preference #{old_pref.name}"
          owner.set_preference old_pref.name, old_pref.value
        end
      rescue => e
        say "Skipping setting preference #{old_pref.owner_type}::#{old_pref.name}"
      end
    end

    # Remove old promotion prefs
    Spree::Preference.where(:key => nil).delete_all

  end

  def down
    remove_column :spree_preferences, :key
    remove_column :spree_preferences, :value_type

    add_column :spree_preferences, :name, :string
    add_column :spree_preferences, :owner_id, :integer
    add_column :spree_preferences, :owner_type, :string
    add_column :spree_preferences, :group_id, :integer
    add_column :spree_preferences, :group_type, :string
  end
end
