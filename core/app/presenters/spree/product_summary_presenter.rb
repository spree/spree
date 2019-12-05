module Spree
  class ProductSummaryPresenter
    include Rails.application.routes.url_helpers

    def initialize(product)
      @product = product
    end

    def call
      {
        name: @product.name,
        images: images
      }
    end

    private

    def images
      @product.images.map do |image|
        {
          url_product: url_for(image.url(:product))
        }
      end
    end
  end
end
