module Spree
  class ProductDuplicator
    attr_accessor :product

    def initialize(product)
      @product = product
    end

    def duplicate
      new_product = duplicate_product

      # don't dup the actual variants, just the characterising types
      new_product.option_types = product.option_types if product.has_variants?

      # allow site to do some customization
      new_product.send(:duplicate_extra, product) if new_product.respond_to?(:duplicate_extra)
      new_product.save!
      new_product
    end

    protected

    def duplicate_product
      product.dup.tap do |new_product|
        new_product.name = "COPY OF #{product.name}"
        new_product.taxons = product.taxons
        new_product.created_at = nil
        new_product.deleted_at = nil
        new_product.updated_at = nil
        new_product.product_properties = reset_properties
        new_product.master = duplicate_variant
      end
    end

    def duplicate_variant
      master.dup.tap do |new_product|
        new_product.sku = "COPY OF #{master.sku}"
        new_product.deleted_at = nil
        new_product.images = master.images.map { |image| duplicate_imag image }
        new_product.price = master.price
        new_product.currency = master.currency
      end
    end

    def duplicate_image(image)
      image.dup.assign_attributes(:attachment => image.attachment.clone)
    end

    def reset_properties
      product.product_properties.map do |prop|
        prop.dup.tap do |new_prop|
          new_prop.created_at = nil
          new_prop.updated_at = nil
        end
      end
    end

    def master
      product.master
    end
  end
end
