FactoryBot.define do
  factory :adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :order)
    association(:source, factory: :tax_rate)

    amount   { 100.0 }
    label    { 'Shipping' }
    eligible { true }
  end

  factory :tax_adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :line_item)
    association(:source, factory: :tax_rate)

    amount   { 10.0 }
    label    { 'VAT 5%' }
    eligible { true }

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
