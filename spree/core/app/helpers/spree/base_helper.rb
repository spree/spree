module Spree
  module BaseHelper
    def spree_dom_id(record)
      dom_id(record, 'spree')
    end

    def available_countries
      countries = current_store.countries_available_for_checkout

      countries.collect do |country|
        country.name = Spree.t(country.iso, scope: 'country_names', default: country.name)
        country
      end.sort_by { |c| c.name.parameterize }
    end

    def all_countries
      countries = Spree::Country.all

      countries.collect do |country|
        country.name = Spree.t(country.iso, scope: 'country_names', default: country.name)
        country
      end.sort_by { |c| c.name.parameterize }
    end

    def object
      instance_variable_get('@' + controller_name.singularize)
    end

    # returns the URL of an object on the storefront
    # @param resource [Spree::Product, Spree::Taxon, Spree::Page] the resource to get the URL for
    # @param options [Hash] the options for the URL
    # @option options [String] :locale the locale of the resource, defaults to I18n.locale
    # @option options [String] :store the store of the resource, defaults to current_store
    # @option options [String] :relative whether to use the relative URL, defaults to false
    # @option options [String] :preview_id the preview ID of the resource, usually the ID of the resource
    # @option options [String] :variant_id the variant ID of the resource, usually the ID of the variant (only used for products)
    # @return [String] the URL of the resource
    def spree_storefront_resource_url(resource, options = {})
      options.merge!(locale: locale_param) if defined?(locale_param) && locale_param.present?

      store = options[:store] || current_store

      base_url = if options[:relative]
                   ''
                 else
                   store.storefront_url
                 end

      localize = if options[:locale].present?
                   "/#{options[:locale]}"
                 else
                   ''
                 end

      if resource.instance_of?(Spree::Product)
        preview_id = ("preview_id=#{options[:preview_id]}" if options[:preview_id].present?)

        variant_id = ("variant_id=#{options[:variant_id]}" if options[:variant_id].present?)

        params = [preview_id, variant_id].compact_blank.join('&')
        params = "?#{params}" if params.present?

        "#{base_url + localize}/products/#{resource.slug}#{params}"
      elsif resource.is_a?(Spree::Taxon)
        "#{base_url + localize}/t/#{resource.permalink}"
      elsif defined?(Spree::Page) && (resource.is_a?(Spree::Page) || resource.is_a?(Spree::Policy))
        "#{base_url + localize}#{resource.page_builder_url}"
      elsif defined?(Spree::PageLink) && resource.is_a?(Spree::PageLink)
        resource.linkable_url
      elsif localize.blank?
        base_url
      else
        base_url + localize
      end
    end

    # we should always try to render image of the default variant
    # same as it's done on PDP
    def default_image_for_product(product)
      Spree::Deprecation.warn('BaseHelper#default_image_for_product is deprecated and will be removed in Spree 6.0. Please use product.primary_media instead')

      product.primary_media
    end

    def default_image_for_product_or_variant(product_or_variant)
      Spree::Deprecation.warn('BaseHelper#default_image_for_product_or_variant is deprecated and will be removed in Spree 6.0. Please use product_or_variant.primary_media instead')

      product_or_variant.primary_media
    end

    def spree_base_cache_key
      @spree_base_cache_key ||= [
        I18n.locale,
        (current_currency if defined?(current_currency)),
        defined?(try_spree_current_user) && try_spree_current_user.present?,
        defined?(try_spree_current_user) && try_spree_current_user.respond_to?(:role_users) && try_spree_current_user.role_users.cache_key_with_version
      ].compact
    end

    def spree_base_cache_scope
      ->(record = nil) { [*spree_base_cache_key, record].compact_blank }
    end

    def payment_method_icon_tag(payment_method, opts = {})
      return '' unless defined?(inline_svg)

      opts[:width] ||= opts[:height] * 1.5 if opts[:height]
      opts[:size] = "#{opts[:width]}x#{opts[:height]}" if opts[:width] && opts[:height]

      opts[:fallback] = 'payment_icons/storecredit.svg'

      inline_svg "payment_icons/#{payment_method}.svg", opts
    end

    private

    I18N_PLURAL_MANY_COUNT = 2.1
    def plural_resource_name(resource_class)
      resource_class.model_name.human(count: I18N_PLURAL_MANY_COUNT)
    end
  end
end
