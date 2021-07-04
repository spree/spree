module Spree
  module Admin
    module StoresHelper
      def admin_current_store_products_path
        spree.admin_products_path(q: { stores_id_in: current_store.id })
      end

      def admin_current_store_orders_path
        spree.admin_orders_path(q: { store_id_in: current_store.id })
      end

      def admin_current_store_payment_methods_path
        spree.admin_payment_methods_path(q: { stores_id_in: current_store.id })
      end

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

      def store_switch_tab(store, query = :store_id_in)
        link_to store.unique_name, params.merge({ q: { query => store.id, } }).permit!,
                class: "nav-link #{'active' if params[:q][query] == store.id.to_s}"
      end
    end
  end
end
