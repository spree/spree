FactoryBot.define do
  factory :image, class: Spree::Asset do
    media_type { 'image' }

    before(:create) do |image|
      if image.class.method_defined?(:attachment)
        image.attachment.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'), filename: 'thinking-cat.jpg')
      end
    end
  end
end
