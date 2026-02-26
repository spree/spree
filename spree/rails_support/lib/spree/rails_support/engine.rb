require 'rails/engine'

module Spree
  module RailsSupport
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_rails_support'

      initializer 'spree_rails_support.autoload', before: :set_autoload_paths do |app|
        app.config.autoload_paths += %W[#{root}/lib]
      end

      initializer 'spree_rails_support.dependencies', after: :load_config_initializers do
        Spree.searcher_class = 'Spree::Core::Search::Base'

        Spree::Dependencies.products_sorter = 'Spree::Products::Sort'
        Spree::Dependencies.posts_sorter = 'Spree::Posts::Sort'

        Spree::Dependencies.address_finder = 'Spree::Addresses::Find'
        Spree::Dependencies.country_finder = 'Spree::Countries::Find'
        Spree::Dependencies.current_order_finder = 'Spree::Orders::FindCurrent'
        Spree::Dependencies.completed_order_finder = 'Spree::Orders::FindComplete'
        Spree::Dependencies.credit_card_finder = 'Spree::CreditCards::Find'
        Spree::Dependencies.products_finder = 'Spree::Products::Find'
        Spree::Dependencies.posts_finder = 'Spree::Posts::Find'
        Spree::Dependencies.taxon_finder = 'Spree::Taxons::Find'
        Spree::Dependencies.variant_finder = 'Spree::Variants::Find'
      end
    end
  end
end
