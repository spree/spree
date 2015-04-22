FactoryGirl.define do
  factory :image, class: Spree::Image do
    attachment URI.parse('http://upload.wikimedia.org/wikipedia/en/c/c0/Les_Horribles_Cernettes_in_1992.jpg')
  end
end
