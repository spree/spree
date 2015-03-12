class MigrateOldShippingCalculators < ActiveRecord::Migration
  def up
    Spree::ShippingMethod.all.each do |shipping_method|
      old_calculator_id = ActiveRecord::Base.connection.select_values(
        "SELECT id FROM spree_calculators WHERE calculable_type = 'Spree::ShippingMethod' AND calculable_id = #{shipping_method.id}"
      ).first
      old_calculator_class_name = ActiveRecord::Base.connection.select_values(
        "SELECT type FROM spree_calculators WHERE id = '#{old_calculator_id}'"
      ).first
      next if old_calculator_class_name.start_with? 'Spree::Calculator::Shipping'
      old_calculator_calculable_id = ActiveRecord::Base.connection.select_values(
        "SELECT calculable_id FROM spree_calculators WHERE id = '#{old_calculator_id}'"
      ).first

      new_calculator = eval(old_calculator_class_name.sub("::Calculator::", "::Calculator::Shipping::")).new
      new_calculator.calculable_id = old_calculator_calculable_id
      new_calculator.calculable_type = 'Spree::ShippingMethod'
      new_calculator.preferences.keys.each do |pref|
        preference_key = old_calculator_class_name.snakecase + "/#{pref.to_s}/#{old_calculator_id}"
        old_preference = Spree::Preference.where(key: preference_key).first
        next if old_preference.nil?
        # Preferences can't be read/set by name, you have to prefix preferred_
        pref_method = "preferred_#{pref}"
        new_calculator.send("#{pref_method}=", old_preference.value)
      end
      new_calculator.save
    end
  end

  def down
  end
end
