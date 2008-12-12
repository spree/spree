module TaxonsHelper
  def breadcrumbs(taxon)
    crumbs = "<div class='breadcrumbs'>"
    crumbs += link_to t('Products'), products_url
    unless taxon
      return crumbs += "</div>"
    end
    crumbs += image_tag("breadcrumb.gif")
    unless taxon.ancestors.empty?
      crumbs += taxon.ancestors.reverse.collect { |ancestor| link_to ancestor.name, seo_url(ancestor) }.join( image_tag("breadcrumb.gif") )
      crumbs += image_tag("breadcrumb.gif")
    end
    crumbs += taxon.name
    crumbs += "</div>"
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