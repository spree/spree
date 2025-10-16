module Spree
  class Asset < Spree.base_class
    include Support::ActiveStorage
    include Spree::Metafields
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    EXTERNAL_URL_METAFIELD_KEY = 'external.url'

    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, to: :attachment

    has_one_attached :attachment, service: Spree.public_storage_service_name

    default_scope { includes(attachment_attachment: :blob) }

    store_accessor :private_metadata, :session_uploaded_assets_uuid
    scope :with_session_uploaded_assets_uuid, lambda { |uuid|
      where(session_id: uuid)
    }
    scope :with_external_url, ->(url) { url.present? ? with_metafield_key_value(EXTERNAL_URL_METAFIELD_KEY, url.downcase.strip) : none }

    def product
      @product ||= viewable_type == 'Spree::Variant' ? viewable&.product : nil
    end

    def external_url
      get_metafield(EXTERNAL_URL_METAFIELD_KEY)&.value
    end

    def external_url=(url)
      return if url.blank?

      set_metafield(EXTERNAL_URL_METAFIELD_KEY, url.downcase.strip)
    end
  end
end
