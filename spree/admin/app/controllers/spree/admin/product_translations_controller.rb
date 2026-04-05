module Spree
  module Admin
    class ProductTranslationsController < BaseController
      include Pagy::Method

      before_action :load_locales

      def index
        @total_products = store_product_ids.count
        @coverage = build_coverage
        @products = paginated_products
        @translated_locales_map = build_translated_locales_map(@products.map(&:id))
      end

      private

      def load_locales
        @default_locale = current_store.default_locale
        @locales = (current_store.supported_locales_list - [@default_locale]).sort
      end

      def store_product_ids
        @store_product_ids ||= current_store.product_ids
      end

      def build_coverage
        return [] if @locales.empty?

        counts = Spree::Product::Translation
          .where(spree_product_id: store_product_ids)
          .where(locale: @locales)
          .where.not(name: [nil, ''])
          .group(:locale)
          .count

        @locales.map do |locale|
          translated = counts[locale] || 0
          percentage = @total_products.positive? ? (translated * 100.0 / @total_products).round : 0
          { locale: locale, translated: translated, total: @total_products, percentage: percentage }
        end
      end

      def paginated_products
        scope = current_store.products.order(:name)
        scope = scope.ransack(params[:q]).result if params[:q].present?
        @pagy, products = pagy(scope, limit: params[:per_page] || 25)
        products
      end

      def build_translated_locales_map(product_ids)
        return {} if product_ids.empty? || @locales.empty?

        rows = Spree::Product::Translation
          .where(spree_product_id: product_ids, locale: @locales)
          .where.not(name: [nil, ''])
          .pluck(:spree_product_id, :locale)

        rows.each_with_object({}) do |(product_id, locale), hash|
          (hash[product_id] ||= []) << locale
        end
      end
    end
  end
end
