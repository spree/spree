require 'rails/engine'

module Spree
  module Graphql
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_graphql'

      initializer 'spree.graphqlenvironment', before: :load_config_initializers do |_app|
        Spree::Graphql::Config = Spree::GraphqlConfiguration.new
        Spree::Graphql::Dependencies = Spree::GraphqlDependencies.new
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end
    end
  end
end
