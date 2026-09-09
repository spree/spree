FactoryBot.define do
  factory :package_type, class: Spree::PackageType do
    store { Spree::Store.default || association(:store) }
    sequence(:name) { |n| "Package type #{n}" }
    kind { 'box' }
    dimensions_unit { 'cm' }
    weight_unit { 'kg' }

    factory :carton_package_type do
      kind { 'carton' }
      sequence(:name) { |n| "Carton #{n}" }
      length { 40 }
      width { 30 }
      height { 25 }
      max_weight { 20 }
    end

    # A default box with every measurement the parcel quote needs — what the
    # `PackageType` onboarding requirement asks a seller for.
    trait :measured_default_box do
      default { true }
      length { 30 }
      width { 20 }
      height { 15 }
      weight { 0.4 }
    end

    factory :pallet_package_type do
      kind { 'pallet' }
      sequence(:name) { |n| "Pallet #{n}" }
      length { 120 }
      width { 80 }
      height { 15 }
    end
  end
end
