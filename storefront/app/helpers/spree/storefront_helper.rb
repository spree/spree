module Spree
  module StorefrontHelper
    include BaseHelper
    include Heroicon::Engine.helpers

    def render_storefront_partials(section)
      Rails.application.config.spree_storefront.send(section).map do |partial|
        render partial: partial
      end.join.html_safe
    end

    def page_description
      return @page_description if @page_description.present?

      @page_description = object.meta_description if object.respond_to?(:meta_description)

      if @page_description.blank? && [Spree::Product, Spree::Taxon, Spree::Post].include?(object.class)
        @page_description = truncate(strip_tags(object.description.to_s).strip, length: 160, separator: ' ', escape: false)
      end

      @page_description = current_store.meta_description if @page_description.blank?

      @page_description
    end

    def page_image
      return @page_image if @page_image.present?

      if object.is_a? Spree::Product
        @page_image = object.default_image&.attachment
      elsif object.respond_to?(:image)
        @page_image = object.image
      end

      @page_image ||= current_store.social_image

      @page_image
    end

    def tailwind_classes_for(flash_type)
      {
        notice: 'alert-notice',
        success: 'alert-success',
        error: 'alert-error',
        alert: 'alert-warning',
      }.stringify_keys[flash_type.to_s] || flash_type.to_s
    end

    def as_aspect_ratio(attachment)
      return unless attachment.present?
      return unless attachment.analyzed?

      metadata = attachment.metadata
      aspect_ratio = metadata['aspect_ratio'].presence

      return aspect_ratio if aspect_ratio

      width = metadata['width']&.to_f
      return unless width

      height = metadata['height']&.to_f
      return unless height

      width / height
    end

    def svg_country_icon(country_code)
      country_code = :us if country_code.to_s.downcase == "en"
      tag.span(class: "fi fi-#{country_code.downcase}")
    end
  end
end
