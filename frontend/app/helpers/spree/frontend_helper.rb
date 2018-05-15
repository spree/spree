module Spree
  module FrontendHelper
    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def spree_breadcrumbs(taxon, separator = '&nbsp;')
      return '' if current_page?('/') || taxon.nil?
      separator = raw(separator)
      crumbs = generate_crumbs([], Spree.t(:home), spree.root_path, separator)
      crumbs = if taxon
                 generate_crumbs_with_taxon(crumbs, taxon, separator)
               else
                 generate_crumbs_without_taxon(crumbs)
               end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map(&:mb_chars).join), class: 'breadcrumb', itemscope: 'itemscope', itemtype: 'https://schema.org/BreadcrumbList')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-md-12')
    end

    def breadcrumbs(taxon, separator = '&nbsp;')
      ActiveSupport::Deprecation.warn(<<-WARNING_STR, caller)
        Spree::FrontendHelper#breadcrumbs was renamed to Spree::FrontendHelper#spree_breadcrumbs
        and will be removed in Spree 3.6. Please update your code to avoid problems after update
      WARNING_STR
      spree_breadcrumbs(taxon, separator)
    end

    def checkout_progress(numbers: false)
      states = @order.checkout_steps
      items = states.each_with_index.map do |state, i|
        text = Spree.t("order_state.#{state}").titleize
        text.prepend("#{i.succ}. ") if numbers

        css_classes = []
        current_index = states.index(@order.state)
        state_index = states.index(state)

        if state_index < current_index
          css_classes << 'completed'
          text = link_to text, checkout_state_path(state)
        end

        css_classes << 'next' if state_index == current_index + 1
        css_classes << 'active' if state == @order.state
        css_classes << 'first' if state_index.zero?
        css_classes << 'last' if state_index == states.length - 1
        # No more joined classes. IE6 is not a target browser.
        # Hack: Stops <a> being wrapped round previous items twice.
        if state_index < current_index
          content_tag('li', text, class: css_classes.join(' '))
        else
          content_tag('li', content_tag('a', text), class: css_classes.join(' '))
        end
      end
      content_tag('ul', raw(items.join("\n")), class: 'progress-steps nav nav-pills nav-justified', id: "checkout-step-#{@order.state}")
    end

    def flash_messages(opts = {})
      ignore_types = ['order_completed'].concat(Array(opts[:ignore_types]).map(&:to_s) || [])

      flash.each do |msg_type, text|
        concat(content_tag(:div, text, class: "alert alert-#{msg_type}")) unless ignore_types.include?(msg_type)
      end
      nil
    end

    def link_to_cart(text = nil)
      text = text ? h(text) : Spree.t('cart')
      css_class = nil

      if simple_current_order.nil? || simple_current_order.item_count.zero?
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{Spree.t('empty')})"
        css_class = 'empty'
      else
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{simple_current_order.item_count})"\
          "  <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end

      link_to text.html_safe, spree.cart_path, class: "cart-info #{css_class}"
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      return '' if max_level < 1 || root_taxon.leaf?
      content_tag :div, class: 'list-group' do
        taxons = root_taxon.children.map do |taxon|
          css_class = current_taxon && current_taxon.self_and_ancestors.include?(taxon) ? 'list-group-item active' : 'list-group-item'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end
        safe_join(taxons, "\n")
      end
    end

    private

    def generate_crumbs_with_taxon(crumbs, taxon, separator)
      crumbs = generate_crumbs(crumbs, Spree.t(:products), spree.products_path, separator)

      unless taxon.ancestors.empty?
        taxon.ancestors.each do |ancestor|
          crumbs = generate_crumbs(crumbs, ancestor.name, seo_url(ancestor), separator)
        end
      end

      crumbs = generate_active_crumbs(crumbs, taxon.name, seo_url(taxon))
      crumbs
    end

    def generate_crumbs(crumbs, name, path, separator)
      crumbs << content_tag(
        :li,
        content_tag(
          :span,
          link_to(content_tag(:span, name, itemprop: 'name'), path, itemprop: 'url') + separator,
          itemprop: 'item'
        ),
        itemscope: 'itemscope',
        itemtype: 'https://schema.org/ListItem',
        itemprop: 'itemListElement'
      )
      crumbs
    end

    def generate_active_crumbs(crumbs, name, path)
      crumbs << content_tag(
        :li,
        content_tag(
          :span,
          link_to(content_tag(:span, name, itemprop: 'name'), path, itemprop: 'url'),
          itemprop: 'item'
        ),
        class: 'active',
        itemscope: 'itemscope',
        itemtype: 'https://schema.org/ListItem',
        itemprop: 'itemListElement'
      )
      crumbs
    end

    def generate_crumbs_without_taxon(crumbs)
      crumbs << content_tag(
        :li,
        content_tag(:span, Spree.t(:products), itemprop: 'item'),
        class: 'active',
        itemscope: 'itemscope',
        itemtype: 'https://schema.org/ListItem',
        itemprop: 'itemListElement'
      )
      crumbs
    end
  end
end
