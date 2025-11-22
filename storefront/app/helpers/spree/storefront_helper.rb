module Spree
  module StorefrontHelper
    include BaseHelper
    include Spree::ImagesHelper
    include Spree::ShipmentHelper
    include Heroicon::Engine.helpers

    # Returns the cache key for the storefront including the current wishlist and order.
    #
    # @return [Array] The cache key
    def spree_storefront_base_cache_key
      @spree_storefront_base_cache_key ||= [
        spree_base_cache_key,
        current_wishlist,
        current_order
      ].compact
    end

    # Returns the cache scope for the storefront including the current wishlist and order.
    #
    # @return [Proc] The cache scope
    def spree_storefront_base_cache_scope
      ->(record = nil) { [*spree_storefront_base_cache_key, record].compact_blank }
    end

    # Renders the storefront partials for the given section.
    #
    # @param section [String] The section to render
    # @param options [Hash] The options/variables to pass to the partials
    # @return [String] The rendered partials
    def render_storefront_partials(section, options = {})
      Spree.storefront.partials.send(section.to_s.gsub('_partials', '').to_sym).map do |partial|
        render partial, options
      end.join.html_safe
    end

    # Returns the page description for the current page.
    #
    # @return [String] The page description
    def page_description
      return @page_description if @page_description.present?

      @page_description = object.meta_description if object.respond_to?(:meta_description)

      if @page_description.blank? && [Spree::Product, Spree::Taxon, Spree::Post].include?(object.class)
        @page_description = truncate(strip_tags(object.description.to_s).strip, length: 160, separator: ' ', escape: false)
      end

      @page_description = current_store.meta_description if @page_description.blank?

      @page_description
    end

    # Returns the page image for the current page.
    # This is used for SEO, social media and Open Graph tags.
    #
    # @return [String] The page image
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
      Spree::Deprecation.warn('as_aspect_ratio is deprecated. Please use spree_asset_aspect_ratio instead.')
      spree_asset_aspect_ratio(attachment)
    end

    def svg_country_icon(country_code)
      language_to_country = {
        'en' => 'us',
        'ja' => 'jp',
        'uk' => 'ua'
      }

      normalized_code = country_code.to_s.downcase
      final_country_code = language_to_country.fetch(normalized_code, normalized_code)

      tag.span(class: "fi fi-#{final_country_code}")
    end

    def show_account_pane?
      !try_spree_current_user &&
        defined?(spree_login_path) && !paths_equal?(canonical_path, spree_login_path) &&
        defined?(spree_signup_path) && !paths_equal?(canonical_path, spree_signup_path) &&
        defined?(spree_forgot_password_path) && !paths_equal?(canonical_path, spree_forgot_password_path)
    end

    def paths_equal?(path1, path2)
      path1 = URI.parse(path1).path.chomp('/')
      path2 = URI.parse(path2).path.chomp('/')

      path1 == path2
    end
  end
end
