module Spree
  class DigitalAsset < Spree.base_class
    has_prefix_id :dig

    publishes_lifecycle_events

    belongs_to :variant, class_name: 'Spree::Variant'
    has_many :digital_links, class_name: 'Spree::DigitalLink', dependent: :destroy

    has_one_attached :attachment, service: Spree.private_storage_service_name

    # A blank provider_type is the uploaded-file default; the provider class
    # says whether an attachment is required, so file assets keep today's rule
    # and provider-backed assets (which carry no file) are exempt.
    DEFAULT_PROVIDER = 'Spree::DigitalAssetProvider::File'.freeze

    validates :attachment, attached: true, if: -> { provider_class.requires_attachment? }
    validate :provider_type_is_registered, if: -> { provider_type.present? }
    validates :authorized_clicks, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :authorized_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    delegate :product, to: :variant
    delegate :filename, :content_type, :byte_size, to: :attachment

    # Download allowances fall back to the owning store's settings when the
    # asset leaves them blank, so a catalog can mix evergreen files with
    # time-limited ones without changing the store default.
    #
    # The store is passed in by the caller, which already holds it — resolving
    # it here would walk variant → product → store for every link checked.
    #
    # @param store [Spree::Store]
    # @return [Integer]
    def effective_authorized_clicks(store = self.store)
      authorized_clicks || store.preferred_digital_asset_authorized_clicks
    end

    # @param store [Spree::Store]
    # @return [Integer]
    def effective_authorized_days(store = self.store)
      authorized_days || store.preferred_digital_asset_authorized_days
    end

    # @return [Spree::Store] the store this asset's product belongs to
    def store
      product.store
    end

    # The strategy that produces this asset's deliverable. A blank provider_type
    # resolves to the uploaded-file default, exactly as DeliveryMethod resolves
    # its provider — so an unset column is a File asset, not an error.
    #
    # @return [Class]
    def provider_class
      (provider_type.presence || DEFAULT_PROVIDER).safe_constantize || DEFAULT_PROVIDER.constantize
    end

    # Produces the deliverable for one authorized download — a redirect URL or
    # an inline value — via the provider. Callers stay out of the storage layer
    # so a provider-backed asset can answer without an attachment.
    #
    # @param digital_link [Spree::DigitalLink]
    # @param expires_in [ActiveSupport::Duration]
    # @return [Spree::DigitalDelivery, nil]
    def deliver(digital_link, expires_in:)
      provider_class.new(self).deliver(digital_link, expires_in: expires_in)
    end

    # @return [Boolean] whether there is anything to hand to a customer
    def downloadable?
      attachment.attached?
    end

    # @param expires_in [ActiveSupport::Duration] lifetime of the signed URL
    # @return [String, nil] nil when there is nothing to download
    def download_url(expires_in:)
      return unless downloadable?

      attachment.url(expires_in: expires_in, disposition: :attachment)
    end

    private

    # A provider_type must name a registered provider — a stale class name from
    # a removed gem, or a typo, is rejected rather than blowing up at download.
    def provider_type_is_registered
      return if Spree.digital_asset_providers.map(&:to_s).include?(provider_type)

      errors.add(:provider_type, :not_registered)
    end

    # The legacy digital.* events are dual-emitted for one release
    # (webhook contract bridge — removed in 6.1).
    def publish_create_event
      publish_event('digital.created')
      super
    end

    # Cannot call super like its siblings: touch_only_update? clears its flags
    # when read, so the guard must run exactly once for both event names.
    def publish_update_event
      return if touch_only_update?

      publish_event('digital.updated')
      publish_event("#{event_prefix}.updated")
    end

    def publish_delete_event
      publish_event('digital.deleted', @_pre_destroy_payload || event_payload)
      super
    end
  end
end
