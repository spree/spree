Rails.application.routes.draw do
  <%= 'mount Spree::Core::Engine => "/"' if defined?(Spree::Core) %>
end
