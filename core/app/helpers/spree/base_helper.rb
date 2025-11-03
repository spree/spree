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
      last_word = resource.class.name.split('::', 10).last

      spree_class_name_as_path(last_word)
    end

    def spree_class_name_as_path(class_name)
      class_name.underscore.humanize.parameterize(separator: '_')
    end

    def display_price(product_or_variant)
      product_or_variant.
        price_in(current_currency).
        display_price_including_vat_for(current_price_options).
        to_html
    end

    def display_compare_at_price(product_or_variant)
      product_or_variant.
        price_in(current_currency).
        display_compare_at_price_including_vat_for(current_price_options).
        to_html
    end

    def link_to_tracking(shipment, options = {})
      return unless shipment.tracking && shipment.shipping_method

      options[:target] ||= :blank

      if shipment.tracking_url
        link_to(shipment.tracking, shipment.tracking_url, options)
      else
        content_tag(:span, shipment.tracking)
      end
    end

    def spree_favicon_path
      if current_store.favicon.present?
        main_app.cdn_image_url(current_store.favicon)
      else
        url_for('favicon.ico')
      end
    end

    def object
      instance_variable_get('@' + controller_name.singularize)
    end

    def og_meta_data
      og_meta = {}

      if object.is_a? Spree::Product
        image                             = default_image_for_product_or_variant(object)
        og_meta['og:image']               = main_app.cdn_image_url(image.attachment) if image&.attachment

        og_meta['og:url']                 = spree.url_for(object) if frontend_available? # url_for product needed
        og_meta['og:type']                = object.class.name.demodulize.downcase
        og_meta['og:title']               = object.name
        og_meta['og:description']         = object.description

        price = object.price_in(current_currency)
        if price
          og_meta['product:price:amount']   = price.amount
          og_meta['product:price:currency'] = current_currency
        end
      end

      og_meta
    end

    def meta_data
      meta = {}

      if object.is_a? ApplicationRecord
        meta[:keywords] = object.meta_keywords if object.try(:meta_keywords).present?
        meta[:description] = object.meta_description if object.try(:meta_description).present?
      end

      if meta[:description].blank? && object.is_a?(Spree::Product)
        meta[:description] = truncate(strip_tags(object.description), length: 160, separator: ' ')
      end

      if meta[:keywords].blank? || meta[:description].blank?
        if object && object[:name].present?
          meta.reverse_merge!(keywords: [object.name, current_store.meta_keywords].reject(&:blank?).join(', '),
                              description: [object.name, current_store.meta_description].reject(&:blank?).join(', '))
        else
          meta.reverse_merge!(keywords: (current_store.meta_keywords || current_store.seo_title),
                              description: current_store.seo_meta_description)
        end
      end
      meta
    end

    def og_meta_data_tags
      og_meta_data.map do |property, content|
        tag('meta', property: property, content: content) unless property.nil? || content.nil?
      end.join("\n")
    end

    def meta_data_tags
      meta_data.map do |name, content|
        tag('meta', name: name, content: content) unless name.nil? || content.nil?
      end.join("\n")
    end

    def method_missing(method_name, *args, &block)
      if image_style = image_style_from_method_name(method_name)
        define_image_method(image_style)
        send(method_name, *args)
      else
        super
      end
    end

    def pretty_time(time)
      return '' if time.blank?

      Spree::Deprecation.warn('BaseHelper#pretty_time is deprecated and will be removed in Spree 6.0. Please add `local_time` gem to your Gemfile and use `local_time(time)` instead')

      [I18n.l(time.to_date, format: :long), time.strftime('%l:%M %p %Z')].join(' ')
    end

    def pretty_date(date)
      return '' if date.blank?

      Spree::Deprecation.warn('BaseHelper#pretty_date is deprecated and will be removed in Spree 6.0. Please add `local_time` gem to your Gemfile and use `local_date(date)` instead')

      [I18n.l(date.to_date, format: :long)].join(' ')
    end

    def seo_url(taxon, options = {})
      spree.nested_taxons_path(taxon.permalink, options.merge(locale: locale_param))
    end

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end

    # returns the URL of an object on the storefront
    # @param resource [Spree::Product, Spree::Post, Spree::Taxon, Spree::Page] the resource to get the URL for
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
                 elsif store.formatted_custom_domain.blank?
                   store.formatted_url
                 else
                   store.formatted_custom_domain
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
      elsif resource.is_a?(Post)
        preview_id = options[:preview_id].present? ? "?preview_id=#{options[:preview_id]}" : ''
        "#{base_url + localize}/posts/#{resource.slug}#{preview_id}"
      elsif resource.is_a?(Spree::Taxon)
        "#{base_url + localize}/t/#{resource.permalink}"
      elsif resource.is_a?(Spree::Page) || resource.is_a?(Spree::Policy)
        "#{base_url + localize}#{resource.page_builder_url}"
      elsif resource.is_a?(Spree::PageLink)
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
      Spree::Deprecation.warn('BaseHelper#default_image_for_product is deprecated and will be removed in Spree 6.0. Please use product.default_image instead')

      product.default_image
    end

    def default_image_for_product_or_variant(product_or_variant)
      Spree::Deprecation.warn('BaseHelper#default_image_for_product_or_variant is deprecated and will be removed in Spree 6.0. Please use product_or_variant.default_image instead')

      product_or_variant.default_image
    end

    def base_cache_key
      Spree::Deprecation.warn('`base_cache_key` is deprecated and will be removed in Spree 6. Please use `spree_base_cache_key` instead')
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
      Spree::DatabaseTypeUtilities.maximum_value_for(:integer)
    end

    def payment_method_icon_tag(payment_method, opts = {})
      return '' unless defined?(inline_svg)

      opts[:width] ||= opts[:height] * 1.5 if opts[:height]
      opts[:size] = "#{opts[:width]}x#{opts[:height]}" if opts[:width] && opts[:height]

      inline_svg "payment_icons/#{payment_method}.svg", opts
    end

    private

    def create_product_image_tag(image, product, options, style)
      options[:alt] = image.alt.blank? ? product.name : image.alt
      image_tag main_app.cdn_image_url(image.url(style)), options
    end

    def define_image_method(style)
      self.class.send :define_method, "#{style}_image" do |product, *options|
        options = options.first || {}
        options[:alt] ||= product.name
        image_path = default_image_for_product_or_variant(product)
        img = if image_path.present?
                create_product_image_tag image_path, product, options, style
              else
                width = style.to_s.split('x').first.to_i
                height = style.to_s.split('x').last.to_i
                content_tag(:div, width: width, height: height, style: "background-color: #f0f0f0;")
              end

        content_tag(:div, img, class: "admin-product-image-container #{style}-img")
      end
    end

    # Returns style of image or nil
    def image_style_from_method_name(method_name)
      style = method_name.to_s.sub(/_image$/, '')
      if method_name.to_s.match(/_image$/) && Spree::Image.styles.keys.map(&:to_s).include?(style)
        style
      end
    end

    def meta_robots
      return unless current_store.respond_to?(:seo_robots)
      return if current_store.seo_robots.blank?

      tag('meta', name: 'robots', content: current_store.seo_robots)
    end

    def legal_policy(policy)
      current_store.send("customer_#{policy}")&.body&.html_safe
    end

    I18N_PLURAL_MANY_COUNT = 2.1
    def plural_resource_name(resource_class)
      resource_class.model_name.human(count: I18N_PLURAL_MANY_COUNT)
    end
  end
end
