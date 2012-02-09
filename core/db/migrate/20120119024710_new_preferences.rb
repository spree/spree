class NewPreferences < ActiveRecord::Migration

  class OldPrefs < ActiveRecord::Base
    self.table_name = "spree_preferences"
    belongs_to  :owner, :polymorphic => true
    attr_accessor :owner_klass
  end

  def up
    add_column :spree_preferences, :key, :string
    add_column :spree_preferences, :value_type, :string
    add_index :spree_preferences, :key, :unique => true

    remove_index :spree_preferences, :name => 'ix_prefs_on_owner_attr_pref'

    # remove old constraints for migration
    change_column :spree_preferences, :name, :string, :null => true
    change_column :spree_preferences, :owner_id, :integer, :null => true
    change_column :spree_preferences, :owner_type, :string, :null => true
    change_column :spree_preferences, :group_id, :integer, :null => true
    change_column :spree_preferences, :group_type, :string, :null => true

    spree_config = Spree::AppConfiguration.new
    Spree::Preference.where(:owner_type => 'Spree::Configuration').each do |preference|
      preference.key = spree_config.preference_cache_key(preference.name)
      preference.value_type = spree_config.preference_type(preference.name)
      preference.save(:validate => false)
    end

    OldPrefs.all.each do |old_pref|
      next unless owner = (old_pref.owner rescue nil)
      unless old_pref.owner_type == "Spree::Activator" || old_pref.owner_type == "Spree::Configuration"
        old_pref.key = [owner.class.name, old_pref.name, owner.id].join('::').underscore
        old_pref.value_type = owner.preference_type(old_pref.name)
        say "Migrating Preference: #{old_pref.key}"
        old_pref.save
      end
    end
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
