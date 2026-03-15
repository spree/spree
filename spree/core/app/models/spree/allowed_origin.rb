# frozen_string_literal: true

module Spree
  class AllowedOrigin < Spree.base_class
    has_prefix_id :ao

    include Spree::SingleStoreResource

    belongs_to :store, class_name: 'Spree::Store'

    validates :store, :origin, presence: true
    validates :origin, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }
    validate :origin_must_be_valid_http_url

    private

    def origin_must_be_valid_http_url
      return if origin.blank?

      uri = URI.parse(origin)

      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        errors.add(:origin, :invalid)
        return
      end

      if uri.host.blank?
        errors.add(:origin, :invalid)
        return
      end

      # Origins must not have a path, query, or fragment
      if uri.path.present? && uri.path != '/'
        errors.add(:origin, :must_be_origin_only)
      end

      if uri.query.present? || uri.fragment.present?
        errors.add(:origin, :must_be_origin_only)
      end
    rescue URI::InvalidURIError
      errors.add(:origin, :invalid)
    end
  end
end
