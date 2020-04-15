module Spree
  module MailHelper
    include BaseHelper

    def variant_image_url(variant)
      image = variant.images.first
      image ? main_app.url_for(image.url(:small)) : 'noimage/small.png'
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end
  end
end
