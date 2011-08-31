FactoryGirl.define do
  factory :state do
    name 'ALABAMA'
    abbr 'AL'
    country do
      if usa = Country.find_by_numcode(840)
        usa
      else
        association :country
      end
    end
  end
end