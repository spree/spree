module TaxonsHelper
  def breadcrumbs(taxon, separator="&nbsp;&raquo;&nbsp;", linked = true)
    return "" if current_page?("/")
    separator = raw(separator)
    crumbs = [content_tag(:li, breadcrumb(t(:home) , root_path, linked) + separator)]
    if taxon
      crumbs << content_tag(:li, breadcrumb(t('products') , products_path, linked) + separator)
      crumbs << taxon.ancestors.collect { |ancestor| content_tag(:li, breadcrumb(ancestor.name || name, seo_url(ancestor), linked) + separator) } unless taxon.ancestors.empty?
      crumbs << content_tag(:li, content_tag(:span, taxon.name))
    else
      crumbs << content_tag(:li, content_tag(:span, t('products')))
    end
    crumb_list = content_tag(:ul, raw(crumbs.flatten.map{|li| li.mb_chars}.join))
    content_tag(:div, crumb_list + tag(:br, {:class => 'clear'}, false, true), :class => 'breadcrumbs')
  end


  # Retrieves the collection of products to display when "previewing" a taxon.  This is abstracted into a helper so
  # that we can use configurations as well as make it easier for end users to override this determination.  One idea is
  # to show the most popular products for a particular taxon (that is an exercise left to the developer.)
  def taxon_preview(taxon, max=5)
    products = taxon.products.active.find(:all, :limit => max)
    if (products.size < max) && Spree::Config[:show_descendents]
      taxon.descendants.each do |taxon|
        to_get = max - products.length
        products += taxon.products.active.find(:all, :limit => to_get)
        break if products.size >= max
      end
    end
    products
  end

  private
  def breadcrumb( text, link_path, linked = true )
    linked  ? link_to(text, link_path)  : text
  end
end
