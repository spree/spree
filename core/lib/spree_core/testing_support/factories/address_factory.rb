FactoryGirl.define do
  factory :address do
    firstname 'John'
    lastname 'Doe'
    address1 '10 Lovely Street'
    address2 'Northwest'
    city   'Herndon'
    zipcode '20170'
    phone '123-456-7890'
    alternative_phone '123-456-7899'

    state { association :state }
    country do
      if state
        state.country
      else
        association :country
      end
    end
  end
end