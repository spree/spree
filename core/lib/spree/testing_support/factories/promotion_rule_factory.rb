FactoryBot.define do
  factory :promotion_rule, class: Spree::PromotionRule do
    association :promotion
  end

  factory :promotion_rule_user, class: Spree::Promotion::Rules::User do
    association :promotion
  end

  factory :promotion_rule_product, class: Spree::Promotion::Rules::Product do
    association :promotion
  end

  factory :promotion_rule_taxon, class: Spree::Promotion::Rules::Taxon do
    association :promotion
  end

  factory :promotion_rule_option_value, class: Spree::Promotion::Rules::OptionValue do
    association :promotion
  end
end
