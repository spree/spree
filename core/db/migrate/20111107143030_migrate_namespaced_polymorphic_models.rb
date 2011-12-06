class MigrateNamespacedPolymorphicModels < ActiveRecord::Migration
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
  
  def up
    update_column_data(['spree_payments', 'spree_adjustments', 'spree_log_entries'], 'source_type')
    update_column_data('spree_adjustments', 'originator_type')
    update_column_data('spree_calculators', 'calculable_type')
    update_column_data('spree_preferences', 'owner_type')
    update_column_data('spree_state_events', 'stateful_type')
    update_column_data(['spree_activators', 'spree_assets', 'spree_calculators', 'spree_configurations', 'spree_gateways', 'spree_payment_methods'], 'type')
    update_column_data('spree_assets', 'viewable_type')
    update_column_data('spree_zone_members', 'zoneable_type')
  end

  def down
    replace_column_data(['spree_payments', 'spree_adjustments', 'spree_log_entries'], 'source_type')
    replace_column_data('spree_adjustments', 'originator_type')
    replace_column_data('spree_calculators', 'calculable_type')
    replace_column_data('spree_preferences', 'owner_type')
    replace_column_data('spree_state_events', 'stateful_type')
    replace_column_data(['spree_activators', 'spree_assets', 'spree_calculators', 'spree_configurations', 'spree_gateways', 'spree_payment_methods'], 'type')
    replace_column_data('spree_assets', 'viewable_type')
    replace_column_data('spree_zone_members', 'zoneable_type')
  end
end
