FactoryBot.define do
  factory :oauth_application, class: Spree::OauthApplication do
    name { "Admin Panel" }
    scopes { "admin" }
  end
end
