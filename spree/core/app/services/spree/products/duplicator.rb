module Spree
  module Products
    class Duplicator
      prepend ::Spree::ServiceModule::Base

      def call(product:, include_images: true)
        new_product = duplicate_product(product, include_images)

        # don't dup the actual variants, just the characterising types. Gate on
        # option_types (not has_variants?, which is >1) so a single option-bearing
        # variant still carries its option types across.
        new_product.option_types = product.option_types if product.option_types.any?

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

          new_product.status = :draft
          new_product.name = "COPY OF #{product.name}"
          new_product.categories = product.categories
          new_product.channels = product.channels
          new_product.created_at = nil
          new_product.deleted_at = nil
          new_product.updated_at = nil
          new_product.tag_list = product.tag_list
          new_product.default_variant_id = nil
          new_product.variants = product.variants.map { |variant| duplicate_variant(variant, include_images) }
        end
      end

      def duplicate_variant(variant, include_images)
        new_variant = variant.dup
        new_variant.sku = sku_generator(new_variant.sku)
        new_variant.deleted_at = nil
        new_variant.option_values = variant.option_values.map { |option_value| option_value }
        new_variant.prices = duplicate_prices(variant.prices)
        new_variant.stock_items = duplicate_stock_items(variant.stock_items)

        variant.images.each { |image| duplicate_image(image, new_variant) } if include_images

        new_variant
      end

      def duplicate_prices(prices)
        prices.map do |price|
          new_price = price.dup
          new_price.created_at = nil
          new_price.updated_at = nil
          new_price
        end
      end

      def duplicate_stock_items(stock_items)
        stock_items.map do |stock_item|
          new_stock_item = stock_item.dup
          new_stock_item.count_on_hand = 0
          new_stock_item
        end
      end

      def duplicate_image(image, viewable)
        new_image = image.dup
        new_image.viewable = viewable
        new_image.attachment.attach(image.attachment.blob)
        new_image.save
        new_image
      end

      def sku_generator(sku)
        return '' if sku.blank?

        "COPY OF #{Variant.unscoped.where('sku like ?', "%#{sku}").order(:created_at).last.sku}"
      end

      def duplicate_error_message(new_product)
        errors = []
        errors << new_product.errors.full_messages

        new_product.variants.each do |variant|
          errors << variant.errors.full_messages
        end

        errors.flatten.to_sentence
      end
    end
  end
end
