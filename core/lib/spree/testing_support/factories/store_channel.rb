FactoryBot.define do
  factory :store_channel, class: Spree::StoreChannel do
    name { generate(:random_string) }

    before(:create) do |store_channel|
      if store_channel.store.nil?
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        store_channel.store = store
      end
    end
  end
end
