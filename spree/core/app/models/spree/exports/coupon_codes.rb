module Spree
  module Exports
    class CouponCodes < Spree::Export
      def csv_headers
        Spree::CSV::CouponCodePresenter::HEADERS
      end

      def scope_includes
        [:promotion, :order]
      end

      def scope
        model_class.joins(promotion: :stores).where(spree_stores: { id: store.id })
                   .accessible_by(current_ability)
      end
    end
  end
end
