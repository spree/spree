module Spree
  class ProductDuplicator
    attr_accessor :product

    @@clone_images_default = true
    mattr_accessor :clone_images_default

    def initialize(product, include_images = @@clone_images_default)
      @product = product
      @include_images = include_images
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
        new_product.master = duplicate_master
        new_product.variants = product.variants.map { |variant| duplicate_variant variant }
      end
    end

    def duplicate_master
      master = product.master
      master.dup.tap do |new_master|
        new_master.sku = sku_generator(master.sku)
        new_master.deleted_at = nil
        new_master.images = master.images.map { |image| duplicate_image image } if @include_images
        new_master.price = master.price
        new_master.currency = master.currency
      end
    end

    def duplicate_variant(variant)
      new_variant = variant.dup
      new_variant.sku = sku_generator(new_variant.sku)
      new_variant.deleted_at = nil
      new_variant.option_values = variant.option_values.map { |option_value| option_value }
      new_variant
    end

    def duplicate_image(image)
      new_image = image.dup
      new_image.attachment.attach(image.attachment.blob)
      new_image.save!
      new_image
    end

    def reset_properties
      product.product_properties.map do |prop|
        prop.dup.tap do |new_prop|
          new_prop.created_at = nil
          new_prop.updated_at = nil
        end
      end
    end

    def sku_generator(sku)
      "COPY OF #{Variant.unscoped.where('sku like ?', "%#{sku}").order(:created_at).last.sku}"
    end
  end
end
