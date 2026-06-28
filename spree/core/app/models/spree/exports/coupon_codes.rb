module Spree
  module Exports
    class CouponCodes < Spree::Export
      def self.required_scope
        :promotions
      end

      def csv_headers
        Spree::CSV::CouponCodePresenter::HEADERS
      end

      def scope_includes
        [:promotion, :order]
      end

      def scope
        model_class.where(promotion: store.promotions).accessible_by(current_ability)
      end
    end
  end
end
