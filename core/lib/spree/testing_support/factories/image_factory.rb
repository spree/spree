FactoryGirl.define do
  factory :image, class: Spree::Image do
    attachment { File.open File.expand_path('../../../../spec/fixtures/thinking-cat.jpg', File.dirname(__FILE__)) }
  end
end
