module Spree
  module Admin
    module ProductsHelper
      def option_type_select(so)
        select(:new_variant,
               so.option_type.presentation,
               so.option_type.option_values.collect { |ov| [ ov.presentation, ov.id ] })
      end

    end
  end
end
