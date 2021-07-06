FactoryBot.define do
  factory :menu, class: Spree::Menu do
    name { generate(:random_string) }
    locale { 'en' }
    location {'Header'}

    transient do
      attach_to_default_store { true }
    end

    before(:create) do |menu, evaluator|
      if evaluator.attach_to_default_store
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        menu.store = store
      end
    end
  end
end
