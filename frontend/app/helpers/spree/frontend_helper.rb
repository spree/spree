module Spree
  module FrontendHelper
    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def class_for(flash_type)
      {
        success: 'success',
        registration_error: 'danger',
        error:   'danger',
        alert:   'danger',
        warning: 'warning',
        notice:  'success'
      }[flash_type.to_sym]
    end

    def flash_messages(_opts = {})
      flashes = ''

      flash.to_h.except('order_completed').each do |msg_type, text|
        next if msg_type.blank?
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
          link_content = image_tag('full_circle.svg', class: "checkout-progress-steps-image")
          link_content << text
          text = link_to(link_content, checkout_state_path(state), class: "d-flex flex-column align-items-center", method: :get)
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
          if state == @order.state
            link_content = image_tag('full_circle.svg', class: "checkout-progress-steps-image")
          else
            link_content = image_tag('circle.svg', class: "checkout-progress-steps-image")
          end
          link_content << text
          content_tag('li', content_tag('a', link_content, class: "d-flex flex-column align-items-center #{'active' if state == @order.state}"), class: css_classes.join(' '))
        end
      end
      content = content_tag('ul', raw(items.join("\n")), class: 'nav justify-content-between checkout-progress-steps', id: "checkout-step-#{@order.state}")
      content << content_tag('div', raw('<hr /><hr /><hr />'), class: "checkout-progress-steps-line state-#{@order.state}")
    end

    def asset_exists?(path)
      if Rails.env.production?
        Rails.application.assets_manifest.find_sources(path).present?
      else
        Rails.application.assets.find_asset(path).present?
      end
    end

    def carousel_image(product, image_class)
      image = product.master.images.first
      image_url = image&.plp_url || asset_path('noimage/plp.png')
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

    def plp_image(product, image_class)
      image = product.master.images.first
      image_url = image&.plp_url || asset_path('noimage/plp.png')
      image_dimensions = image&.style_dimensions(:plp)

      lazy_image(
        src: image_url,
        alt: product.name,
        width: image_dimensions&.dig(:width) || 278,
        height: image_dimensions&.dig(:height) || 371,
        class: "product-component-image d-block mw-100 #{image_class}"
      )
    end

    def main_nav_image(category, type)
      image_path = "#{type}_#{category}.jpg"
      image_url = asset_path(asset_exists?(image_path) ? image_path : 'noimage/plp.png')

      lazy_image(
        src: image_url,
        alt: category,
        width: 350,
        height: 234
      )
    end

    def lazy_image(src:, alt:, width:, height:, srcset:'', **options)
      # We need placeholder image with the correct size to prevent page from jumping
      placeholder = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20#{width}%20#{height}'%3E%3C/svg%3E"

      image_tag placeholder, data: { src: src, srcset: srcset }, class: "#{options[:class]} lazyload", alt: alt
    end

    def spree_breadcrumbs(taxon, separator = '', product = nil)
      return '' if current_page?('/') || taxon.nil?

      separator = raw(separator)
      crumbs = [content_tag(:li, content_tag(:span, link_to(content_tag(:span, Spree.t(:home), itemprop: 'name'), spree.root_path, itemprop: 'url') + separator, itemprop: 'item'), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')]
      if taxon
        crumbs << taxon.ancestors.where.not(parent_id: nil).map { |ancestor| content_tag(:li, content_tag(:span, link_to(content_tag(:span, ancestor.name, itemprop: 'name'), seo_url(ancestor, params: permitted_product_params), itemprop: 'url') + separator, itemprop: 'item'), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item') } unless taxon.ancestors.empty?
        crumbs << content_tag(:li, content_tag(:span, link_to(content_tag(:span, taxon.name, itemprop: 'name'), seo_url(taxon, params: permitted_product_params), itemprop: 'url') + separator, itemprop: 'item'), class: 'breadcrumb-item', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
        crumbs << content_tag(:li, content_tag(:span, content_tag(:span, product.name) + separator), class: 'breadcrumb-item') if product
      else
        crumbs << content_tag(:li, content_tag(:span, Spree.t(:products), itemprop: 'item'), class: 'active', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
      end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map(&:mb_chars).join), class: 'breadcrumb', itemscope: 'itemscope', itemtype: 'https://schema.org/BreadcrumbList')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-12 mt-1 mt-sm-3 mt-lg-4', aria: { label: 'breadcrumb' })
    end

    def permitted_product_params
      product_filters = Rails.cache.fetch('spree/product-filters', expires_in: 5.minutes) { Spree::OptionType.pluck(:name) }
      params.permit(product_filters << :sort_by)
    end

    def carousel_image_source_set(image)
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

    def icon(name:, classes: '', width:, height:)
      inline_svg "#{name}.svg", class: "spree-icon #{classes}", size: "#{width}px*#{height}px"
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
  end
end
