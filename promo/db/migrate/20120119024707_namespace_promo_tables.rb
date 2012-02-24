require 'spree/core/preference_rescue'

class NamespacePromoTables < ActiveRecord::Migration

  def concat(str1, str2)
    dbtype = Rails.configuration.database_configuration[Rails.env]['adapter'].to_sym

    case dbtype
    when :mysql, :mysql2
      "CONCAT(#{str1}, #{str2})"
    when :sqlserver
      "(#{str1} + #{str2})"
    else
      "(#{str1} || #{str2})"
    end
  end

  def update_column_data(table_names, column_name)
    tables = Array.wrap(table_names)
    tables.each do |table|
      execute "UPDATE #{table} SET #{column_name} = #{concat("'Spree::'", column_name)}" +
        " where #{column_name} NOT LIKE 'Spree::%' AND #{column_name} IS NOT NULL"
    end
  end

  def replace_column_data(table_names, column_name)
    tables = Array.wrap(table_names)
    tables.each do |table|
      execute "UPDATE #{table} SET #{column_name} = REPLACE(#{column_name}, 'Spree::', '') " +
        " where #{column_name} LIKE 'Spree::%'"
    end
  end

  def self.up
    # namespace promo tables
    rename_table :promotion_actions, :spree_promotion_actions
    rename_table :promotion_rules, :spree_promotion_rules
    rename_table :promotion_rules_users, :spree_promotion_rules_users
    rename_table :promotion_action_line_items, :spree_promotion_action_line_items
    rename_table :products_promotion_rules, :spree_products_promotion_rules

    update_column_data('spree_promotion_actions', 'type')
    update_column_data('spree_promotion_rules', 'type')

    # add old promo preferences as columns
    add_column :spree_activators, :usage_limit, :integer
    add_column :spree_activators, :match_policy, :string, :default => 'all'
    add_column :spree_activators, :code, :string
    add_column :spree_activators, :advertise, :boolean, :default => false

    Spree::Activator.reset_column_information

    Spree::Preference.where(:owner_type => 'Spree::Activator').each do |preference|
      unless Spree::Activator.exists? preference.owner_id
        preference.destroy
        next
      end

      @activator = Spree::Activator.find(preference.owner_id)
      @activator.update_attribute(preference.name, preference.raw_value)
      preference.destroy
    end

    Spree::PreferenceRescue.try

    # This *should* be in the new_preferences migration inside of Core but...
    # This is migration needs to have these keys around so that
    # we can convert the promotions over correctly.
    # So they hang around until we're *finally* done with them, since promo's
    # migrations are copied over *after* core, and then we ditch them.
    remove_column :spree_preferences, :group_id
    remove_column :spree_preferences, :group_type
  end

  def self.down
    replace_column_data('spree_promotion_actions', 'type')
    replace_column_data('spree_promotion_rules', 'type')

    rename_table :spree_promotion_actions, :promotion_actions
    rename_table :spree_promotion_rules, :promotion_rules
    rename_table :spree_promotion_rules_users, :promotion_rules_users
    rename_table :spree_promotion_action_line_items, :promotion_action_line_items
    rename_table :spree_products_promotion_rules, :products_promotion_rules
  end
end