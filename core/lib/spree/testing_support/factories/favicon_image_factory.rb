FactoryBot.define do
  factory :favicon_image, class: Spree::StoreFaviconImage do
    transient do
      filepath { Spree::Core::Engine.root.join('spec', 'fixtures', 'favicon.ico') }
    end

    attachment { Rack::Test::UploadedFile.new(filepath) }
  end
end
