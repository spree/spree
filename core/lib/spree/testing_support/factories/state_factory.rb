FactoryGirl.define do
  factory :state, class: Spree::State do
    name 'Alabama'
    abbr 'AL'
    country do |country|
      if usa = Spree::Country.find_by_numcode(840)
        country = usa
      else
        country.association(:country)
      end
    end
  end

  factory :nc_state, class: Spree::State do
    name 'North Carolina'
    abbr 'NC'
    country do |country|
      if usa = Spree::Country.find_by_numcode(840)
        country = usa
      else
        country.association(:country)
      end
    end

    factory :nv_state do
      name 'Nevada'
      abbr 'NV'
    end
  end
end
