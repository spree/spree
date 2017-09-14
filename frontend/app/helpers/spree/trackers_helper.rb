module Spree
  module TrackersHelper
    def product_for_segment(product, optional = {})
      {
        product_id: product.id,
        sku: product.sku,
        category: product.category.try(:name),
        name: product.name,
        brand: product.brand.try(:name),
        price: product.price,
        currency: product.currency,
        url: product_url(product),
      }.tap do |hash|
        hash[:image_url] = asset_url(optional.delete(:image).attachment) if optional[:image]
      end.merge(optional).to_json.html_safe
    end
  end
end
