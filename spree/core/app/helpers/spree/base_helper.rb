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

    def spree_resource_path(resource)
      Spree::Deprecation.warn('BaseHelper#spree_resource_path is deprecated and will be removed in Spree 5.5')

      last_word = resource.class.name.split('::', 10).last

      spree_class_name_as_path(last_word)
    end

    def spree_class_name_as_path(class_name)
      Spree::Deprecation.warn('BaseHelper#spree_class_name_as_path is deprecated and will be removed in Spree 5.5')

      class_name.underscore.humanize.parameterize(separator: '_')
    end

    def display_price(product_or_variant)
      Spree::Deprecation.warn('display_price is deprecated and will be removed in Spree 5.5. Use variant.price_for(context).display_amount instead.')

      product_or_variant.
        price_in(current_currency).
        display_price_including_vat_for(current_price_options).
        to_html
    end

    def display_compare_at_price(product_or_variant)
      Spree::Deprecation.warn('display_compare_at_price is deprecated and will be removed in Spree 5.5. Use variant.price_for(context).display_compare_at_amount instead.')

      product_or_variant.
        price_in(current_currency).
        display_compare_at_price_including_vat_for(current_price_options).
        to_html
    end

    def link_to_tracking(shipment, options = {})
      Spree::Deprecation.warn('BaseHelper#link_to_tracking is deprecated and will be removed in Spree 5.5. Please use shipment.tracking_url instead.')

      return unless shipment.tracking && shipment.shipping_method

      options[:target] ||= :blank

      if shipment.tracking_url
        link_to(shipment.tracking, shipment.tracking_url, options)
      else
        content_tag(:span, shipment.tracking)
      end
    end

    def object
      instance_variable_get('@' + controller_name.singularize)
    end

    def pretty_time(time)
      return '' if time.blank?

      Spree::Deprecation.warn('BaseHelper#pretty_time is deprecated and will be removed in Spree 5.5. Please add `local_time` gem to your Gemfile and use `local_time(time)` instead')

      [I18n.l(time.to_date, format: :long), time.strftime('%l:%M %p %Z')].join(' ')
    end

    def pretty_date(date)
      return '' if date.blank?

      Spree::Deprecation.warn('BaseHelper#pretty_date is deprecated and will be removed in Spree 5.5. Please add `local_time` gem to your Gemfile and use `local_date(date)` instead')

      [I18n.l(date.to_date, format: :long)].join(' ')
    end

    def seo_url(taxon, options = {})
      Spree::Deprecation.warn('BaseHelper#seo_url is deprecated and will be removed in Spree 5.5. Please use spree_storefront_resource_url')
      spree.nested_taxons_path(taxon.permalink, options.merge(locale: locale_param))
    end

    def frontend_available?
      Spree::Deprecation.warn('BaseHelper#frontend_available? is deprecated and will be removed in Spree 5.5')
      Spree::Core::Engine.frontend_available?
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
                 elsif store.respond_to?(:formatted_custom_domain) && store.formatted_custom_domain.present?
                   store.formatted_custom_domain
                 else
                   store.formatted_url
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
      Spree::Deprecation.warn('BaseHelper#default_image_for_product is deprecated and will be removed in Spree 5.5. Please use product.default_image instead')

      product.default_image
    end

    def default_image_for_product_or_variant(product_or_variant)
      Spree::Deprecation.warn('BaseHelper#default_image_for_product_or_variant is deprecated and will be removed in Spree 5.5. Please use product_or_variant.default_image instead')

      product_or_variant.default_image
    end

    def base_cache_key
      Spree::Deprecation.warn('`base_cache_key` is deprecated and will be removed in Spree 5.5. Please use `spree_base_cache_key` instead')
      spree_base_cache_key
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

    def maximum_quantity
      Spree::Deprecation.warn('BaseHelper#maximum_quantity is deprecated and will be removed in Spree 5.5')
      Spree::DatabaseTypeUtilities::INTEGER_MAX
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
