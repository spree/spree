FactoryBot.define do
  factory :import, class: 'Spree::Import' do
    owner { Spree::Store.default || create(:store) }
    association :user, factory: :admin_user
    type { 'Spree::Imports::Products' }

    factory :product_import, class: 'Spree::Imports::Products', parent: :import do
      type { 'Spree::Imports::Products' }
      # attachment { Rack::Test::UploadedFile.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'files', 'products_import.csv'), 'text/csv') }

      after(:create) do |import|
        import.attachment.attach(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'files', 'products_import.csv')),
          filename: 'products_import.csv',
          content_type: 'text/csv'
        )
      end
    end

    factory :customer_import, class: 'Spree::Imports::Customers', parent: :import do
      type { 'Spree::Imports::Customers' }

      after(:create) do |import|
        import.attachment.attach(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'files', 'customers_import.csv')),
          filename: 'customers_import.csv',
          content_type: 'text/csv'
        )
      end
    end
  end
end
