module TaxonsHelper
  def breadcrumbs(taxon)
    crumbs = []
    crumbs << link_to(t('products'), products_url)
    if taxon
      unless taxon.ancestors.empty?
        crumbs += taxon.ancestors.reverse.collect { |ancestor| link_to ancestor.name, seo_url(ancestor) }
      end
      crumbs << taxon.name
    end
    content_tag('p', crumbs.join(' <span class="divider">&raquo;</span> '), :id => 'breadcrumbs')
  end

  
  # Retrieves the collection of products to display when "previewing" a taxon.  This is abstracted into a helper so 
  # that we can use configurations as well as make it easier for end users to override this determination.  One idea is
  # to show the most popular products for a particular taxon (that is an exercise left to the developer.) 
  def taxon_preview(taxon)
    products = taxon.products.active[0..4]
    return products unless products.size < 5
    if Spree::Config[:show_descendents]
      taxon.descendents.each do |taxon|
        products += taxon.products.active[0..4]
        break if products.size >= 5
      end
    end
    products[0..4]
  end
end