FactoryGirl.define do
  factory :adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :order)
    amount 100.0
    label 'Shipping'
    association(:source, factory: :tax_rate)
    eligible true
  end

  factory :tax_adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :line_item)
    amount 10.0
    label 'VAT 5%'
    association(:source, factory: :tax_rate)
    eligible true

    after(:create) do |adjustment|
      # Set correct tax category, so that adjustment amount is not 0
      if adjustment.adjustable.is_a?(Spree::LineItem)
        adjustment.source.tax_category = adjustment.adjustable.tax_category
        adjustment.source.save
        adjustment.update!
      end
    end
  end
end
