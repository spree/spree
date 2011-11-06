Rails.application.routes.draw do
  <%= 'mount Spree::Auth::Engine => "/"' if defined?(Spree::Auth) %>
  <%= 'mount Spree::Api::Engine => "/"' if defined?(Spree::Api) %>
  <%= 'mount Spree::Promo::Engine => "/"' if defined?(Spree::Promo) %>
  <%= 'mount Spree::Dash::Engine => "/"' if defined?(Spree::Dash) %>
  <%= 'mount Spree::Core::Engine => "/"' if defined?(Spree::Core) %>
end
