class NewPreferences < ActiveRecord::Migration

  class OldPrefs < ActiveRecord::Base
    set_table_name "spree_preferences"
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

    # namespace promo tables
    rename_table :promotion_actions, :spree_promotion_actions
    rename_table :promotion_rules, :spree_promotion_rules
    rename_table :promotion_rules_users, :spree_promotion_rules_users
    rename_table :promotion_action_line_items, :spree_promotion_action_line_items
    rename_table :products_promotion_rules, :spree_products_promotion_rules

    # add old promo preferences as columns
    add_column :spree_activators, :usage_limit, :integer
    add_column :spree_activators, :match_policy, :string, :default => 'all'
    add_column :spree_activators, :code, :string
    add_column :spree_activators, :advertise, :boolean, :default => false

    Spree::Promotion.class_eval do
      preference :usage_limit, :integer
      preference :match_policy, :string, :default => 'all'
      preference :code, :string
      preference :advertise, :boolean, :default => false
    end

    # manually update old promotions to use the new promotion style
    Spree::Preference.where(:owner_type => 'Spree::Activator').group_by(&:owner_id).each do |key, pref_group|
      @promo = Spree::Promotion.new
      pref_group.each do |pref|
        case pref.name
        when 'code'
          @promo.code = pref.value.to_s
          @promo.name = pref.value.to_s
        when 'advertise'
          @promo.advertise = pref.value
        when 'usage_limit'
          @promo.usage_limit = pref.value
        when 'match_policy'
          @promo.match_policy = pref.value
        end
        @promo.event_name = Spree::Promotion.find(pref.owner_id).event_name
      end
      @promo.save!
    end

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

    # Remove old promotions
    Spree::Promotion.where(:code => nil).delete_all

    remove_column :spree_preferences, :name
    remove_column :spree_preferences, :owner_id
    remove_column :spree_preferences, :owner_type
    remove_column :spree_preferences, :group_id
    remove_column :spree_preferences, :group_type
  end

  def down
    remove_column :spree_preferences, :key
    remove_column :spree_preferences, :value_type

    add_column :spree_preferences, :name, :string
    add_column :spree_preferences, :owner_id, :integer
    add_column :spree_preferences, :owner_type, :string
    add_column :spree_preferences, :group_id, :integer
    add_column :spree_preferences, :group_type, :string

    rename_table :spree_promotion_actions, :promotion_actions
    rename_table :spree_promotion_rules, :promotion_rules
    rename_table :spree_promotion_rules_users, :promotion_rules_users
    rename_table :spree_promotion_action_line_items, :promotion_action_line_items
    rename_table :spree_products_promotion_rules, :products_promotion_rules
  end
end
