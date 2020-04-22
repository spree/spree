module Spree
  module MailHelper
    include BaseHelper

    def variant_image_url(variant)
      image = default_image_for_product_or_variant(variant)
      image ? main_app.url_for(image.url(:small)) : 'noimage/small.png'
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end
  end
end
