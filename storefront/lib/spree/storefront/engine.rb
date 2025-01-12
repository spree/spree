require_relative 'runtime_configuration'

module Spree
  module Storefront
    class Engine < ::Rails::Engine
      initializer 'spree.storefront.configuration', before: :load_config_initializers do |_app|
        Spree::Storefront::RuntimeConfig = Spree::Storefront::RuntimeConfiguration.new
      end

      initializer 'spree.storefront.assets' do |app|
        app.config.assets.paths << root.join('app/javascript')
        app.config.assets.precompile += %w[ spree_storefront_manifest ]
      end

      initializer 'spree.storefront.importmap', before: 'importmap' do |app|
        app.config.importmap.paths << root.join('config/importmap.rb')
        # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end
    end
  end
end
