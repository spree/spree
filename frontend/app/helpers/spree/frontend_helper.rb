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
      @stores ||= Spree::Store.includes(:default_country).order(:id)
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

    def permitted_product_params
      product_filters = available_option_types.map(&:name)
      params.permit(product_filters << :sort_by)
    end

    def icon(name:, classes: '', width:, height:)
      inline_svg_tag "#{name}.svg", class: "spree-icon #{classes}", size: "#{width}px*#{height}px"
    end

    def spree_social_link(service)
      return '' if current_store.send(service).blank?

      link_to "https://#{service}.com/#{current_store.send(service)}", target: :blank, rel: 'nofollow noopener', 'aria-label': service do
        content_tag :figure, id: service, class: 'px-2' do
          icon(name: service, width: 22, height: 22)
        end
      end
    end
  end
end
