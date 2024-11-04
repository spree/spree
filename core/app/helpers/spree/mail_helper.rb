module Spree
  module MailHelper
    include BaseHelper

    def variant_image_url(variant)
      image = default_image_for_product_or_variant(variant)
      image ? main_app.cdn_image_url(image.url(:small)) : image_url('noimage/small.png')
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end

    def store_logo
      @store_logo ||= current_store&.mailer_logo&.attachment || current_store&.logo&.attachment
    end

    def logo_path
      return main_app.cdn_image_url(store_logo.variant(resize_to_limit: [244, 104])) if store_logo&.variable?

      return main_app.cdn_image_url(store_logo) if store_logo&.image?
    end
  end
end
