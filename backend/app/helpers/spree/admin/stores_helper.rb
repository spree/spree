module Spree
  module Admin
    module StoresHelper
      def selected_checkout_zone(store)
        store&.checkout_zone || Spree::Zone.default_checkout_zone
      end

      def stores_dropdown_values
        formatted_stores = []

        @stores.map { |store| formatted_stores << [store.unique_name, store.id] }

        formatted_stores
      end

    def stores
      @stores ||= Spree::Store.order(:id)
    end

    def store_link(store = nil, html_opts = {})
      store ||= current_store if defined?(current_store)
      return unless store

      link_to "#{store.name}", "#{store.formatted_url}/admin", **html_opts
    end

    end
  end
end
