FactoryBot.define do
  factory :icon, class: Spree::Icon do
    before(:create) do |icon|
      if icon.respond_to? :attachment
        icon.attachment.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'), filename: 'thinking-cat.jpg')
      end
    end
  end
end
