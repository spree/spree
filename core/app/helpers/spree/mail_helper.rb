module Spree
  module MailHelper
    include Spree::BaseHelper
    include Spree::ImagesHelper

    def variant_image_url(variant)
      image = variant.default_image
      image.present? && image.attached? ? spree_image_url(image, width: 100, height: 100, format: :png) : image_url('noimage/small.png')
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end

    def store_logo
      @store_logo ||= current_store&.mailer_logo || current_store&.logo
    end

    def logo_path
      Spree::Deprecation.warn('logo_path is deprecated and will be removed in Spree 6.0. Please use Active Storage URL helpers instead.')

      return main_app.cdn_image_url(store_logo.variant(resize_to_limit: [244, 104])) if store_logo&.variable?

      return main_app.cdn_image_url(store_logo) if store_logo&.image?
    end
  end
end
