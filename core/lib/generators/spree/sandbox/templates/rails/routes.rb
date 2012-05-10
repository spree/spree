Rails.application.routes.draw do
  mount Spree::Api::Engine => "/"
  mount Spree::Promo::Engine => "/"
  mount Spree::Dash::Engine => "/"
  mount Spree::Core::Engine => "/"
end
