FactoryBot.define do
  factory :oauth_application, class: Spree::OauthApplication do
    name { 'Test Application' }
    redirect_uri { '' }
    scopes { '' }
  end
end
