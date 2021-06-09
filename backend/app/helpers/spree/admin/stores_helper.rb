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

      def stores_select()
        collection_select(nil, nil, @stores, :formatted_url, :name, { selected: current_store.formatted_url, prompt: "Select store" }, { onchange: "window.location.href=`${this.value}/admin`", id: "store_select", class: "stores_select" })
      end
    end
  end
end
