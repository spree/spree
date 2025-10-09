module Spree
  module Admin
    module ProductsHelperDecorator
      def product_search_params
        super.merge(
          tags_name_cont: params.dig(:q, :tags_name_cont)
        ).reject { |_, v| v.blank? }
      end
    end
  end
end

Spree::Admin::ProductsHelper.prepend(Spree::Admin::ProductsHelperDecorator)
