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

      def store_switcher_link(store)
        if current_store.id == store.id
          classes = 'disabled bg-light'
          icon = svg_icon name: 'circle-fill.svg', width: '16', height: '16'
        else
          classes = nil
          icon = svg_icon name: 'circle.svg', width: '16', height: '16'
        end

        link_to icon + store.unique_name, store.formatted_url + request.path,
                class: "#{classes} d-flex align-items-center text-dark p-3 dropdown-item"
      end
    end
  end
end
