FactoryBot.define do
  factory :asset, class: Spree::Asset do
    position { 1 }
    alt {}

    after(:build) do |asset|
      if asset.media_type == 'image' && !asset.attachment.attached?
        asset.attachment.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'), filename: 'thinking-cat.jpg')
      end
    end
  end
end
