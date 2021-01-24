module Spree
  module Admin
    class PricesController < ResourceController
      belongs_to 'spree/product', find_by: :slug

      def create
        params.require(:vp).permit!
        params[:vp].each do |variant_id, prices|
          next unless variant_id

          variant = Spree::Variant.find(variant_id)
          next unless variant

          supported_currencies_for_all_stores.each do |currency|
            price = variant.price_in(currency.iso_code)
            price.price = (prices[currency.iso_code]['price'].blank? ? nil : prices[currency.iso_code]['price'])
            price.compare_at_price = (prices[currency.iso_code]['compare_at_price'].blank? ? nil : prices[currency.iso_code]['compare_at_price'])
            price.save! if price.new_record? && price.price || !price.new_record? && price.changed?
          end
        end
        flash[:success] = Spree.t('notice_messages.prices_saved')
        redirect_to admin_product_path(parent)
      end
    end
  end
end
