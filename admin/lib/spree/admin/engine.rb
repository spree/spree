require_relative 'runtime_configuration'

module Spree
  module Admin
    class Engine < ::Rails::Engine
      initializer 'spree.admin.configuration', before: :load_config_initializers do |app|
        Spree::Admin::RuntimeConfig = Spree::Admin::RuntimeConfiguration.new
      end

      initializer "spree.admin.assets" do |app|
        app.config.assets.paths << root.join("app/javascript")
        app.config.assets.precompile += %w[ spree_admin_manifest ]
      end

      initializer 'spree.admin.importmap', before: 'importmap' do |app|
        app.config.importmap.paths << root.join('config/importmap.rb')
        # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end
    end
  end
end
