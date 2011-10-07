FactoryGirl.define do
  factory :state, :class => Spree::State do
    name 'ALABAMA'
    abbr 'AL'
    country do |country|
      if usa = Country.find_by_numcode(840)
        country = usa
      else
        country.association(:country)
      end
    end
  end
end
