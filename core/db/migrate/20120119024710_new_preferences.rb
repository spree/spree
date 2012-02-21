require 'spree/core/preference_rescue'

class NewPreferences < ActiveRecord::Migration

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

    cfgs = execute("select id, type from spree_configurations").to_a
    execute("select id, owner_id, name from spree_preferences where owner_type = 'Spree::Configuration'").each do |pref|
      configuration = cfgs.detect { |c| c[0].to_s == pref[1].to_s }

      value_type = configuration[1].constantize.new.send "preferred_#{pref[2]}_type" rescue 'string'

      execute "UPDATE spree_preferences set `key` = '#{configuration[1].underscore}/#{pref[2]}', `value_type` = '#{value_type}' where id = #{pref[0]}" rescue nil
    end

    # remove orphaned calculator preferences
    Spree::Preference.where(:owner_type => 'Spree::Calculator').each do |preference|
      preference.destroy unless Spree::Calculator.exists? preference.owner_id
    end

    Spree::PreferenceRescue.try

    Spree::Preference.where(:value_type => nil).update_all(:value_type => 'string')
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