module Spree
  module PageBuilderUrl
    extend ActiveSupport::Concern

    included do
      class << self
        attr_reader :page_builder_route_name, :page_builder_callable_params

        def page_builder_route_with(route_name, callable_params = nil)
          @page_builder_route_name = route_name
          @page_builder_callable_params = callable_params
        end
      end
    end

    def page_builder_url
      route_name = self.class.page_builder_route_name.to_s
      return unless page_builder_url_exists?(route_name)

      callable_params = self.class.page_builder_callable_params

      if callable_params.present?
        route_params = callable_params.call(self)
        return if route_params.nil?
      else
        route_params = {}
      end

      Spree::Core::Engine.routes.url_helpers.send(route_name, route_params, locale: locale_for_page_builder_url)
    end

    private

    def page_builder_url_exists?(route_name)
      Spree::Core::Engine.routes.url_helpers.respond_to?(route_name)
    end

    def locale_for_page_builder_url
      store = respond_to?(:store) ? self.store : Spree::Store.default

      if store.supported_locales_list.length > 1 && store.default_locale.to_s != I18n.locale.to_s
        I18n.locale
      else
        nil
      end
    end
  end
end
