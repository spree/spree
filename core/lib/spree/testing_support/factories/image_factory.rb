FactoryBot.define do
  factory :image, class: Spree::Image do
    if Rails.application.config.use_paperclip
      attachment { File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg') }
    else
      before(:create) do |image|
        image.attachment.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'), filename: 'thinking-cat.jpg')
      end
    end
  end
end
