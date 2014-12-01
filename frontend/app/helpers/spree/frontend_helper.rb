module Spree
  module FrontendHelper
    def breadcrumbs(taxon, separator="&nbsp;")
      return "" if current_page?("/") || taxon.nil?
      separator = raw(separator)
      crumbs = [content_tag(:li, content_tag(:span, link_to(Spree.t(:home), spree.root_path, itemprop: "url") + separator, itemprop: "title"), itemscope:"itemscope", itemtype:"http://data-vocabulary.org/Breadcrumb")]
      if taxon
        crumbs << content_tag(:li, content_tag(:span, link_to(Spree.t(:products), products_path, itemprop: "url") + separator, itemprop: "title"), itemscope:"itemscope", itemtype:"http://data-vocabulary.org/Breadcrumb")
        crumbs << taxon.ancestors.collect { |ancestor| content_tag(:li, content_tag(:span, link_to(ancestor.name , seo_url(ancestor), itemprop: "url") + separator, itemprop: "title"), itemscope:"itemscope", itemtype:"http://data-vocabulary.org/Breadcrumb") } unless taxon.ancestors.empty?
        crumbs << content_tag(:li, content_tag(:span, link_to(taxon.name , seo_url(taxon), itemprop: "url"), itemprop: "title"), class: 'active', itemscope:"itemscope", itemtype:"http://data-vocabulary.org/Breadcrumb")
      else
        crumbs << content_tag(:li, content_tag(:span, Spree.t(:products), itemprop: "title"), class: 'active', itemscope:"itemscope", itemtype:"http://data-vocabulary.org/Breadcrumb")
      end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map{|li| li.mb_chars}.join), class: 'breadcrumb')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-md-12')
    end

    def flash_messages(opts = {})
      ignore_types = ["order_completed"].concat(Array(opts[:ignore_types]).map(&:to_s) || [])

      flash.each do |msg_type, text|
        unless ignore_types.include?(msg_type)
          concat(content_tag :div, text, class: "alert alert-#{msg_type}")
        end
      end
      nil
    end

    def link_to_cart(text = nil)
      text = text ? h(text) : Spree.t('cart')
      css_class = nil

      if simple_current_order.nil? or simple_current_order.item_count.zero?
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{Spree.t('empty')})"
        css_class = 'empty'
      else
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{simple_current_order.item_count})  <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end

      link_to text.html_safe, spree.cart_path, :class => "cart-info #{css_class}"
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      return '' if max_level < 1 || root_taxon.children.empty?
      content_tag :div, class: 'list-group' do
        root_taxon.children.map do |taxon|
          css_class = (current_taxon && current_taxon.self_and_ancestors.include?(taxon)) ? 'list-group-item active' : 'list-group-item'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end.join("\n").html_safe
      end
    end
  end
end
