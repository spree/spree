FactoryBot.define do
  factory :menu, class: Spree::Menu do
    name { generate(:random_string) }
    locale { 'en' }
    location { 'Header' }

    before(:create) do |menu|
      if menu.store.nil?
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        menu.store = store
      end
    end
  end
end
