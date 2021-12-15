module Spree
  module MailHelper
    include BaseHelper

    def variant_image_url(variant)
      image = default_image_for_product_or_variant(variant)
      image ? main_app.cdn_image_url(image.url(:small)) : full_asset_url('noimage/small.png')
    end

    def name_for(order)
      order.name || Spree.t('customer')
    end

    def store_logo
      @store_logo ||= current_store&.mailer_logo || current_store&.logo
    end

    def default_logo
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        `MailHelper#default_logo` is deprecated and will be removed in Spree 5.0.
        Please upload a Store logo instead
      DEPRECATION

      full_asset_url('logo/spree_50.png')
    end

    def logo_path
      return default_logo unless store_logo.attached?
      return main_app.cdn_image_url(store_logo.variant(resize_to_limit: [244, 104])) if store_logo.variable?

      return main_app.cdn_image_url(store_logo) if store_logo.image?
    end

    def full_asset_url(path)
      "#{ActionMailer::Base.default_url_options[:host]}#{asset_url(path)}"
    end
  end
end
