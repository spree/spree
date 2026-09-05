module Spree
  # FK column is `media_id`, matching Spree::Media and its table. The `:asset`
  # association name stays readable for one release alongside `:media`.
  class VariantMedia < Spree.base_class
    self.table_name = 'spree_variant_media'

    belongs_to :variant, class_name: 'Spree::Variant', touch: true
    belongs_to :asset, class_name: 'Spree::Media', foreign_key: :media_id, inverse_of: :variant_media

    validates :media_id, uniqueness: { scope: :variant_id }
    validate :asset_belongs_to_variant_product

    after_commit :refresh_variant_thumbnail, on: %i[create destroy]

    # Resolves an array of variant identifiers (prefixed ids or raw ids) to the
    # numeric ids of variants that belong to `product`. Anything else — bad
    # prefix, foreign product, garbage — is dropped. This is the security
    # boundary used by Spree::Media#variant_ids=, so callers (forms, API params)
    # can't link assets to variants from another product.
    def self.resolve_variant_ids(product, variant_ids)
      ids = Array(variant_ids).reject(&:blank?)
      return [] if ids.empty?

      product.variants.filter_map do |variant|
        token = variant.id.to_s
        prefixed = variant.prefixed_id
        variant.id if ids.any? { |id| id.to_s == token || id == prefixed }
      end
    end

    private

    def asset_belongs_to_variant_product
      return if asset.blank? || variant.blank?
      return if asset.product&.id == variant.product_id

      errors.add(:asset, :variant_product_mismatch,
                 message: Spree.t('errors.messages.variant_product_mismatch'))
    end

    def refresh_variant_thumbnail
      variant&.update_thumbnail!
    end
  end
end
