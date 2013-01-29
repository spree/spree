module Spree
  module Admin
    module ImagesHelper
      def options_text_for(image)
        if image.viewable.is_a?(Spree::Variant)
          image.viewable.options_text
        else
          "All"
        end
      end
    end
  end
end

