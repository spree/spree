module Spree
  module FrontendHelper
    include InlineSvg::ActionView::Helpers

    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def store_country_iso(store)
      store ||= current_store
      return unless store
      return unless store.default_country

      store.default_country.iso.downcase
    end

    def stores
      @stores ||= Spree::Store.includes(:default_country)
    end

    def store_currency_symbol(store)
      store ||= current_store
      return unless store
      return unless store.default_currency

      ::Money::Currency.find(store.default_currency).symbol
    end

    def spree_breadcrumbs(taxon, _separator = '', product = nil)
      return '' if current_page?('/') || taxon.nil?

      # breadcrumbs for root
      crumbs = [content_tag(:li, content_tag(
        :a, content_tag(
          :span, Spree.t(:home), itemprop: 'name'
        ) << content_tag(:meta, nil, itemprop: 'position', content: '0'), itemprop: 'url', href: spree.root_path
      ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: spree.root_path), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')]

      if taxon
        ancestors = taxon.ancestors.where.not(parent_id: nil)

        # breadcrumbs for ancestor taxons
        crumbs << ancestors.each_with_index.map do |ancestor, index|
          content_tag(:li, content_tag(
            :a, content_tag(
              :span, ancestor.name, itemprop: 'name'
            ) << content_tag(:meta, nil, itemprop: 'position', content: index + 1), itemprop: 'url', href: seo_url(ancestor, params: permitted_product_params)
          ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: seo_url(ancestor, params: permitted_product_params)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')
        end

        # breadcrumbs for current taxon
        crumbs << content_tag(:li, content_tag(
          :a, content_tag(
            :span, taxon.name, itemprop: 'name'
          ) << content_tag(:meta, nil, itemprop: 'position', content: ancestors.size + 1), itemprop: 'url', href: seo_url(taxon, params: permitted_product_params)
        ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: seo_url(taxon, params: permitted_product_params)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')

        # breadcrumbs for product
        if product
          crumbs << content_tag(:li, content_tag(
            :span, content_tag(
              :span, product.name, itemprop: 'name'
            ) << content_tag(:meta, nil, itemprop: 'position', content: ancestors.size + 2), itemprop: 'url', href: spree.product_path(product, taxon_id: taxon&.id)
          ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: spree.product_path(product, taxon_id: taxon&.id)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')
        end
      else
        # breadcrumbs for product on PDP
        crumbs << content_tag(:li, content_tag(
          :span, Spree.t(:products), itemprop: 'item'
        ) << content_tag(:meta, nil, itemprop: 'position', content: '1'), class: 'active', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
      end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map(&:mb_chars).join), class: 'breadcrumb', itemscope: 'itemscope', itemtype: 'https://schema.org/BreadcrumbList')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-12 mt-1 mt-sm-3 mt-lg-4', aria: { label: Spree.t(:breadcrumbs) })
    end

    def class_for(flash_type)
      {
        success: 'success',
        registration_error: 'danger',
        error: 'danger',
        alert: 'danger',
        warning: 'warning',
        notice: 'success'
      }[flash_type.to_sym]
    end

    def checkout_progress(numbers: false)
      states = @order.checkout_steps - ['complete']
      items = states.each_with_index.map do |state, i|
        text = Spree.t("order_state.#{state}").titleize
        text.prepend("#{i.succ}. ") if numbers

        css_classes = ['text-uppercase nav-item']
        current_index = states.index(@order.state)
        state_index = states.index(state)

        if state_index < current_index
          css_classes << 'completed'
          link_content = content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
          link_content << text
          text = link_to(link_content, spree.checkout_state_path(state), class: 'd-flex flex-column align-items-center', method: :get)
        end

        css_classes << 'next' if state_index == current_index + 1
        css_classes << 'active' if state == @order.state
        css_classes << 'first' if state_index == 0
        css_classes << 'last' if state_index == states.length - 1
        # No more joined classes. IE6 is not a target browser.
        # Hack: Stops <a> being wrapped round previous items twice.
        if state_index < current_index
          content_tag('li', text, class: css_classes.join(' '))
        else
          link_content = if state == @order.state
                           content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
                         else
                           inline_svg_tag 'circle.svg', class: 'checkout-progress-steps-image'
                         end
          link_content << text
          content_tag('li', content_tag('a', link_content, class: "d-flex flex-column align-items-center #{'active' if state == @order.state}"), class: css_classes.join(' '))
        end
      end
      content = content_tag('ul', raw(items.join("\n")), class: 'nav justify-content-between checkout-progress-steps', id: "checkout-step-#{@order.state}")
      hrs = '<hr />' * (states.length - 1)
      content << content_tag('div', raw(hrs), class: "checkout-progress-steps-line state-#{@order.state}")
    end

    def flash_messages(opts = {})
      flashes = ''
      excluded_types = opts[:excluded_types].to_a.map(&:to_s)

      flash.to_h.except('order_completed').each do |msg_type, text|
        next if msg_type.blank? || excluded_types.include?(msg_type)

        flashes << content_tag(:div, class: "alert alert-#{class_for(msg_type)} mb-0") do
          content_tag(:button, '&times;'.html_safe, class: 'close', data: { dismiss: 'alert', hidden: true }) +
            content_tag(:span, text)
        end
      end
      flashes.html_safe
    end

    def link_to_cart(text = nil)
      text = text ? h(text) : Spree.t('cart')
      css_class = nil

      if simple_current_order.nil? || simple_current_order.item_count.zero?
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{Spree.t('empty')})"
        css_class = 'empty'
      else
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{simple_current_order.item_count})
                <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end

      link_to text.html_safe, spree.cart_path, class: "cart-info nav-link #{css_class}"
    end

    def asset_exists?(path)
      if Rails.env.production?
        Rails.application.assets_manifest.find_sources(path).present?
      else
        Rails.application.assets.find_asset(path).present?
      end
    end

    def plp_and_carousel_image(product, image_class = '')
      image = default_image_for_product_or_variant(product)

      image_url = if image.present?
                    main_app.url_for(image.url('plp'))
                  else
                    asset_path('noimage/plp.png')
                  end

      image_style = image&.style(:plp)

      lazy_image(
        src: image_url,
        srcset: carousel_image_source_set(image),
        alt: product.name,
        width: image_style&.dig(:width) || 278,
        height: image_style&.dig(:height) || 371,
        class: "product-component-image d-block mw-100 #{image_class}"
      )
    end

    def lazy_image(src:, alt:, width:, height:, srcset: '', **options)
      # We need placeholder image with the correct size to prevent page from jumping
      placeholder = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20#{width}%20#{height}'%3E%3C/svg%3E"

      image_tag placeholder, data: { src: src, srcset: srcset }, class: "#{options[:class]} lazyload", alt: alt
    end

    def permitted_product_params
      product_filters = available_option_types.map(&:name)
      params.permit(product_filters << :sort_by)
    end

    def carousel_image_source_set(image)
      return '' unless image

      widths = { lg: 1200, md: 992, sm: 768, xs: 576 }
      set = []
      widths.each do |key, value|
        file = main_app.url_for(image.url("plp_and_carousel_#{key}"))

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def image_source_set(name)
      widths = {
        desktop: '1200',
        tablet_landscape: '992',
        tablet_portrait: '768',
        mobile: '576'
      }
      set = []
      widths.each do |key, value|
        filename = key == :desktop ? name : "#{name}_#{key}"
        file = asset_path("#{filename}.jpg")

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      return '' if max_level < 1 || root_taxon.leaf?

      content_tag :div, class: 'list-group' do
        taxons = root_taxon.children.map do |taxon|
          css_class = current_taxon&.self_and_ancestors&.include?(taxon) ? 'list-group-item list-group-item-action active' : 'list-group-item list-group-item-action'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end
        safe_join(taxons, "\n")
      end
    end

    def set_image_alt(image)
      return image.alt if image.alt.present?
    end

    def icon(name:, classes: '', width:, height:)
      inline_svg_tag "#{name}.svg", class: "spree-icon #{classes}", size: "#{width}px*#{height}px"
    end

    def price_filter_values
      [
        "#{I18n.t('activerecord.attributes.spree/product.less_than')} #{formatted_price(50)}",
        "#{formatted_price(50)} - #{formatted_price(100)}",
        "#{formatted_price(101)} - #{formatted_price(150)}",
        "#{formatted_price(151)} - #{formatted_price(200)}",
        "#{formatted_price(201)} - #{formatted_price(300)}"
      ]
    end

    def static_filters
      @static_filters ||= Spree::Frontend::Config[:products_filters]
    end

    def additional_filters_partials
      @additional_filters_partials ||= Spree::Frontend::Config[:additional_filters_partials]
    end

    def filtering_params
      @filtering_params ||= available_option_types.map(&:filter_param).concat(static_filters)
    end

    def filtering_params_cache_key
      @filtering_params_cache_key ||= params.permit(*filtering_params)&.reject { |_, v| v.blank? }&.to_param
    end

    def available_option_types_cache_key
      @available_option_types_cache_key ||= Spree::OptionType.maximum(:updated_at)&.utc&.to_i
    end

    def available_option_types
      @available_option_types ||= Rails.cache.fetch("available-option-types/#{available_option_types_cache_key}") do
        Spree::OptionType.includes(:option_values).to_a
      end
      @available_option_types
    end

    def spree_social_link(service)
      return '' if current_store.send(service).blank?

      link_to "https://#{service}.com/#{current_store.send(service)}", target: :blank, rel: 'nofollow noopener', 'aria-label': service do
        content_tag :figure, id: service, class: 'px-2' do
          icon(name: service, width: 22, height: 22)
        end
      end
    end

    def checkout_available_payment_methods
      @order.available_payment_methods(current_store)
    end

    private

    def formatted_price(value)
      Spree::Money.new(value, currency: current_currency, no_cents_if_whole: true).to_s
    end

    def credit_card_icon(type)
      available_icons = %w[visa american_express diners_club discover jcb maestro master]

      if available_icons.include?(type)
        image_tag "credit_cards/icons/#{type}.svg", class: 'payment-sources-list-item-image'
      else
        image_tag 'credit_cards/icons/generic.svg', class: 'payment-sources-list-item-image'
      end
    end

    def checkout_edit_link(step = 'address')
      classes = 'align-text-bottom checkout-confirm-delivery-informations-link'

      link_to spree.checkout_state_path(step), class: classes, method: :get do
        inline_svg_tag 'edit.svg'
      end
    end
  end
end
