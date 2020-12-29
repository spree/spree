FactoryBot.define do
  factory :state, class: Spree::State do
    sequence(:name) { |n| "STATE_NAME_#{n}" }
    sequence(:abbr) { |n| "STATE_ABBR_#{n}" }
    country do |country|
      usa = Spree::Country.find_by(numcode: 840)
      usa.present? ? usa : country.association(:country)
    end
  end
end
