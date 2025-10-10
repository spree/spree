require_relative 'configuration'

module Spree
  module Storefront
    class Engine < ::Rails::Engine
      Environment = Struct.new(
        :head_partials,
        :body_start_partials,
        :body_end_partials,
        :cart_partials,
        :add_to_cart_partials,
        :remove_from_cart_partials,
        :checkout_partials,
        :checkout_complete_partials,
        :quick_checkout_partials,
        :product_partials,
        :add_to_wishlist_partials
      )

      # accessible via Rails.application.config.spree_storefront
      initializer 'spree.storefront.environment', before: :load_config_initializers do |app|
        app.config.spree_storefront = Environment.new
      end

      initializer 'spree.storefront.configuration', before: :load_config_initializers do |_app|
        Spree::Storefront::Config = Spree::Storefront::Configuration.new
      end

      initializer 'spree.storefront.assets' do |app|
        app.config.assets.paths << root.join('app/javascript')
        app.config.assets.paths << root.join('vendor/javascript')
        app.config.assets.precompile += %w[spree_storefront_manifest]
      end

      initializer 'spree.storefront.importmap', before: 'importmap' do |app|
        app.config.importmap.paths << root.join('config/importmap.rb')
        # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end

      # we need to set the path to the storefront so that tailwind can find the views
      initializer 'spree.storefront.tailwind_views_path' do
        ENV['SPREE_STOREFRONT_PATH'] = root.to_s
      end

      config.after_initialize do
        Rails.application.config.spree_storefront.head_partials = []
        Rails.application.config.spree_storefront.body_start_partials = []
        Rails.application.config.spree_storefront.body_end_partials = []
        Rails.application.config.spree_storefront.cart_partials = []
        Rails.application.config.spree_storefront.add_to_cart_partials = []
        Rails.application.config.spree_storefront.remove_from_cart_partials = []
        Rails.application.config.spree_storefront.checkout_partials = []
        Rails.application.config.spree_storefront.checkout_complete_partials = []
        Rails.application.config.spree_storefront.quick_checkout_partials = []
        Rails.application.config.spree_storefront.product_partials = []
        Rails.application.config.spree_storefront.add_to_wishlist_partials = []
      end
    end
  end
end
