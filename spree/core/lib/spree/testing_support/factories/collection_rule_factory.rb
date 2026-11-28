FactoryBot.define do
  factory :sale_collection_rule, class: Spree::CollectionRules::Sale do
    value { true }

    trait :is_equal_to do
      match_policy { 'is_equal_to' }
    end

    trait :is_not_equal_to do
      match_policy { 'is_not_equal_to' }
    end

    trait :contains do
      match_policy { 'contains' }
    end

    trait :does_not_contain do
      match_policy { 'does_not_contain' }
    end
  end

  factory :tag_collection_rule, class: Spree::CollectionRules::Tag do
    trait :is_equal_to do
      match_policy { 'is_equal_to' }
    end

    trait :is_not_equal_to do
      match_policy { 'is_not_equal_to' }
    end

    trait :contains do
      match_policy { 'contains' }
    end

    trait :does_not_contain do
      match_policy { 'does_not_contain' }
    end
  end

  factory :available_on_collection_rule, class: Spree::CollectionRules::AvailableOn do
    value { 30 }

    trait :is_equal_to do
      match_policy { 'is_equal_to' }
    end
  end
end

FactoryBot.define do
  factory :category_collection_rule, class: Spree::CollectionRules::Category do
    match_policy { 'is_equal_to' }
  end

  factory :product_type_collection_rule, class: Spree::CollectionRules::ProductType do
    match_policy { 'is_equal_to' }
  end

  factory :seller_collection_rule, class: Spree::CollectionRules::Seller do
    match_policy { 'is_equal_to' }
  end

  factory :price_collection_rule, class: Spree::CollectionRules::Price do
    match_policy { 'less_than' }
    value { '50' }
  end

  factory :in_stock_collection_rule, class: Spree::CollectionRules::InStock do
    match_policy { 'is_equal_to' }
  end

  factory :title_collection_rule, class: Spree::CollectionRules::Title do
    match_policy { 'contains' }
  end

  factory :custom_field_collection_rule, class: Spree::CollectionRules::CustomField do
    match_policy { 'is_equal_to' }
  end
end
