module Spree
  module MailHelper
    include Spree::BaseHelper
    include Spree::ImagesHelper

    def variant_image_url(variant)
      image = variant.primary_media
      image.present? && image.attached? ? spree_image_url(image, variant: :mini) : image_url('noimage/small.png')
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end

    def store_logo
      @store_logo ||= current_store&.mailer_logo || current_store&.logo
    end
  end
end
