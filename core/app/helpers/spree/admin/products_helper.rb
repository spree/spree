module Spree
  module Admin
    module ProductsHelper
      def taxon_options_for(product)
        options = @taxons.map do |taxon|
          selected = product.taxons.include?(taxon)
          content_tag(:option,
                      :value    => taxon.id,
                      :selected => ('selected' if selected)) do
            taxon.name
          end
        end.join("").html_safe
      end
    end
  end
end
