module Spree
  module Admin
    class VariantsIncludingMasterController < VariantsController
      belongs_to "spree/product", find_by: :slug

      def model_class
        Spree::Variant
      end

      def object_name
        "variant"
      end

    end
  end
end
