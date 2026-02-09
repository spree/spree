# This migration comes from spree (originally 20241104083457)
class MigrateSpreePromotionRulesOptionValueEligibleValues < ActiveRecord::Migration[6.1]
  def change
    Spree::Promotion::Rules::OptionValue.find_each do |option_value|
      new_eligible_values = option_value.preferred_eligible_values.flat_map do |product_id, option_value_ids|
        value_ids = option_value_ids.is_a?(String) ? option_value_ids.split(',') : option_value_ids

        Spree::OptionValueVariant.
          joins(:variant).
          where(option_value_id: value_ids, "#{Spree::Variant.table_name}.product_id" => product_id).
          pluck(:id)
      end

      option_value.update!(preferred_eligible_values: new_eligible_values)
    end
  end
end
