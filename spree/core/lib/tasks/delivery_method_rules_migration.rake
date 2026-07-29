# frozen_string_literal: true

# 5.6 → 6.0: fold the FlatRate calculator's eligibility bound preferences
# into DeliveryMethodRule rows (docs/plans/6.0-delivery-method-rules.md).
# The calculator preferences keep working as a deprecation bridge through
# 6.0; this task moves the data so the bridge can drop in 6.1.
namespace :spree do
  desc 'Convert FlatRate calculator eligibility bounds into delivery method rules'
  task migrate_calculator_bounds_to_delivery_method_rules: :environment do
    converted = 0

    Spree::Calculator::Shipping::FlatRate.where(calculable_type: %w[Spree::DeliveryMethod Spree::ShippingMethod]).find_each do |calculator|
      delivery_method = Spree::DeliveryMethod.unscoped.find_by(id: calculator.calculable_id)
      next unless delivery_method

      prefs = calculator.preferences || {}
      min_total = prefs[:minimum_item_total]
      max_total = prefs[:maximum_item_total]
      min_weight = prefs[:minimum_weight]
      max_weight = prefs[:maximum_weight]

      if (min_total.present? || max_total.present?) &&
          !delivery_method.delivery_method_rules.exists?(type: 'Spree::DeliveryMethodRules::ItemTotalRule')
        delivery_method.delivery_method_rules.create!(
          type: 'Spree::DeliveryMethodRules::ItemTotalRule',
          preferences: { minimum_amount: min_total, maximum_amount: max_total }
        )
        converted += 1
      end

      if (min_weight.present? || max_weight.present?) &&
          !delivery_method.delivery_method_rules.exists?(type: 'Spree::DeliveryMethodRules::WeightRule')
        delivery_method.delivery_method_rules.create!(
          type: 'Spree::DeliveryMethodRules::WeightRule',
          preferences: { minimum_weight: min_weight, maximum_weight: max_weight }
        )
        converted += 1
      end

      # Clear the migrated bounds so the calculator's legacy nil-guards stop
      # double-enforcing (the rules own eligibility now).
      if min_total.present? || max_total.present? || min_weight.present? || max_weight.present?
        calculator.update_columns(
          preferences: prefs.except(:minimum_item_total, :maximum_item_total, :minimum_weight, :maximum_weight)
        )
      end
    end

    puts "migrate_calculator_bounds_to_delivery_method_rules done. #{converted} rules created."
  end
end
