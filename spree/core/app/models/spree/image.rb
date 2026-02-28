module Spree
  class Image < Asset
    include Spree::Image::Configuration::ActiveStorage # legacy to be removed in Spree 6
    include Rails.application.routes.url_helpers
    include Spree::ImageMethods # legacy, will be removed in Spree 6

    validates :attachment, attached: true, content_type: Rails.application.config.active_storage.web_image_content_types

    after_commit :touch_product_variants, if: :should_touch_product_variants?, on: :update
    after_commit :update_variant_thumbnail, on: [:create, :destroy]
    after_commit :update_variant_thumbnail_on_reorder, on: :update, if: :saved_change_to_position?
    after_commit :update_variant_thumbnail_on_viewable_change, on: :update, if: :saved_change_to_viewable_id?

    after_create :increment_viewable_image_count
    after_destroy :decrement_viewable_image_count

    # In Rails 5.x class constants are being undefined/redefined during the code reloading process
    # in a rails development environment, after which the actual ruby objects stored in those class constants
    # are no longer equal (subclass == self) what causes error ActiveRecord::SubclassNotFound
    # Invalid single-table inheritance type: Spree::Image is not a subclass of Spree::Image.
    # The line below prevents the error.
    self.inheritance_column = nil

    # @deprecated
    def styles
      Spree::Deprecation.warn("Image#styles is deprecated and will be removed in Spree 6.0. Please use active storage variants with cdn_image_url")

      self.class.styles.map do |_, size|
        width, height = size.chop.split('x').map(&:to_i)

        {
          url: generate_url(size: size),
          size: size,
          width: width,
          height: height
        }
      end
    end

    private

    def touch_product_variants
      viewable.product.variants.touch_all
    end

    def should_touch_product_variants?
      viewable.is_a?(Spree::Variant) &&
        viewable.is_master? &&
        viewable.product.has_variants? &&
        saved_change_to_position?
    end

    def increment_viewable_image_count
      return unless viewable.is_a?(Spree::Variant)

      Spree::Variant.increment_counter(:image_count, viewable_id)
      Spree::Product.increment_counter(:total_image_count, viewable.product_id)
    end

    def decrement_viewable_image_count
      return unless viewable.is_a?(Spree::Variant)

      Spree::Variant.decrement_counter(:image_count, viewable_id)
      Spree::Product.decrement_counter(:total_image_count, viewable.product_id)
    end

    def update_variant_thumbnail
      return unless viewable.is_a?(Spree::Variant)

      viewable.update_thumbnail!
      viewable.product.update_thumbnail!
    end

    def update_variant_thumbnail_on_reorder
      update_variant_thumbnail
    end

    def update_variant_thumbnail_on_viewable_change
      update_variant_thumbnail
    end
  end
end
