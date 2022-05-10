module Spree
  module Core
    module ControllerHelpers
      module Search
        def build_searcher(params)
          Spree.searcher_class.new(params).tap do |searcher|
            searcher.current_user = try_spree_current_user
            searcher.current_currency = current_currency&.upcase
            searcher.current_store = current_store
          end
        end
      end
    end
  end
end
