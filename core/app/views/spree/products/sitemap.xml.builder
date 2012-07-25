xml.instruct! :xml, :version => '1.0', :encoding => 'UTF-8'

# create the urlset
xml.urlset :xmlns => 'http://www.sitemaps.org/schemas/sitemap/0.9' do
  # Extension pages
  @products.each do |product|
    xml.url do # create the url entry, with the specified location and date
      xml.loc product_url(product).strip
      xml.lastmod product.updated_at.strftime('%Y-%m-%d')
      xml.changefreq 'daily'
    end
  end
end