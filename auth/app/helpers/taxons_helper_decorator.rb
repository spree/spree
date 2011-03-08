TaxonsHelper.module_eval do
  # adds accessible_by calls to filter out products user shouldn't access
  def taxon_preview(taxon, max=5)
    products = taxon.active_products.accessible_by(current_ability).limit(max)
    if (products.size < max) && Spree::Config[:show_descendents]
      taxon.descendants.each do |taxon|
        to_get = max - products.length
        products += taxon.active_products.accessible_by(current_ability).limit(to_get)
        break if products.size >= max
      end
    end
    products
  end
end
