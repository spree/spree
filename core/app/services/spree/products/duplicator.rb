module Spree
  module Products
    class Duplicator
      prepend ::Spree::ServiceModule::Base

      def call(product:, include_images: true)
        new_product = duplicate_product(product, include_images)

        # don't dup the actual variants, just the characterising types
        new_product.option_types = product.option_types if product.has_variants?

        # allow site to do some customization
        new_product.send(:duplicate_extra, product) if new_product.respond_to?(:duplicate_extra)
        new_product.save

        new_product.persisted? ? success(new_product) : failure(new_product, duplicate_error_message(new_product))
      end

      protected

      def duplicate_product(product, include_images)
        product.dup.tap do |new_product|
          new_product.translations.each do |t|
            t.name = "COPY OF #{t.name}"
            t.slug = nil
          end

          new_product.name = "COPY OF #{product.name}"
          new_product.taxons = product.taxons
          new_product.stores = product.stores
          new_product.created_at = nil
          new_product.deleted_at = nil
          new_product.updated_at = nil
          new_product.master = duplicate_master(product.master, include_images)
          new_product.variants = product.variants.map { |variant| duplicate_variant(variant) }

          duplicate_properties(product.product_properties, new_product)
        end
      end

      def duplicate_master(master, include_images)
        master.dup.tap do |new_master|
          new_master.sku = sku_generator(master.sku)
          new_master.deleted_at = nil
          new_master.price = master.price
          new_master.currency = master.currency

          master.images.each { |image| duplicate_image(image, new_master) } if include_images
        end
      end

      def duplicate_variant(variant)
        new_variant = variant.dup
        new_variant.sku = sku_generator(new_variant.sku)
        new_variant.deleted_at = nil
        new_variant.option_values = variant.option_values.map { |option_value| option_value }
        new_variant
      end

      def duplicate_image(image, viewable)
        new_image = image.dup
        new_image.viewable = viewable
        new_image.attachment.attach(image.attachment.blob)
        new_image.save
        new_image
      end

      def duplicate_properties(product_properties, new_product)
        product_properties.each do |prop|
          new_prop = prop.dup
          new_prop.created_at = nil
          new_prop.updated_at = nil
          new_prop.product = new_product
          new_prop.save
        end
      end

      def sku_generator(sku)
        return '' if sku.blank?

        "COPY OF #{Variant.unscoped.where('sku like ?', "%#{sku}").order(:created_at).last.sku}"
      end

      def duplicate_error_message(new_product)
        errors = []
        errors << new_product.errors.full_messages
        errors << new_product.master.errors.full_messages

        new_product.variants.each do |variant|
          errors << variant.errors.full_messages
        end

        errors.flatten.to_sentence
      end
    end
  end
end
