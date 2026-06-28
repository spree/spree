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
        model_class.joins(:promotion).where(Spree::Promotion.table_name => { store_id: store.id })
                   .accessible_by(current_ability)
      end
    end
  end
end
