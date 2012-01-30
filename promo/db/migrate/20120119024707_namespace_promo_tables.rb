class NamespacePromoTables < ActiveRecord::Migration
  def self.up
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

    # Remove old promotions
    Spree::Promotion.where(:code => nil).delete_all

    # This *should* be in the new_preferences migration inside of Core but...
    # This is migration needs to have these keys around so that
    # we can convert the promotions over correctly.
    # So they hang around until we're *finally* done with them, since promo's
    # migrations are copied over *after* core, and then we ditch them.
    remove_column :spree_preferences, :name
    remove_column :spree_preferences, :owner_id
    remove_column :spree_preferences, :owner_type
    remove_column :spree_preferences, :group_id
    remove_column :spree_preferences, :group_type
  end

  def self.down
    rename_table :spree_promotion_actions, :promotion_actions
    rename_table :spree_promotion_rules, :promotion_rules
    rename_table :spree_promotion_rules_users, :promotion_rules_users
    rename_table :spree_promotion_action_line_items, :promotion_action_line_items
    rename_table :spree_products_promotion_rules, :products_promotion_rules
  end
end
