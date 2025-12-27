module Spree
  class Asset < Spree.base_class
    include Support::ActiveStorage
    include Spree::Metafields
    include Spree::Metadata

    EXTERNAL_URL_METAFIELD_KEY = 'external.url'

    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, :variation, to: :attachment

    WEBP_SAVER_OPTIONS = {
      strip: true,
      quality: 75,
      lossless: false,
      alpha_q: 85,
      reduction_effort: 6,
      smart_subsample: true
    }.freeze

    has_one_attached :attachment, service: Spree.public_storage_service_name do |attachable|
      # Note: Key order matters for variation digest matching.
      # Active Storage reorders keys alphabetically when calling variant(:name),
      # so we must define them in alphabetical order: format, resize_to_fill, saver
      #
      # IMPORTANT: Use string values (not symbols) for format because the variation key
      # is JSON-encoded in URLs. JSON converts symbols to strings, so "webp" != :webp
      # after round-tripping, which causes digest mismatches.
      Spree::Config.product_image_variant_sizes.each do |name, (width, height)|
        attachable.variant name,
                           format: "webp",
                           resize_to_fill: [width, height],
                           saver: WEBP_SAVER_OPTIONS,
                           preprocessed: true
      end
    end

    default_scope { includes(attachment_attachment: :blob) }

    store_accessor :private_metadata, :session_uploaded_assets_uuid
    scope :with_session_uploaded_assets_uuid, lambda { |uuid|
      where(session_id: uuid)
    }
    scope :with_external_url, ->(url) { url.present? ? with_metafield_key_value(EXTERNAL_URL_METAFIELD_KEY, url.strip) : none }

    def product
      @product ||= viewable_type == 'Spree::Variant' ? viewable&.product : nil
    end

    def external_url
      get_metafield(EXTERNAL_URL_METAFIELD_KEY)&.value
    end

    def external_url=(url)
      set_metafield(EXTERNAL_URL_METAFIELD_KEY, url.strip)
    end

    def skip_import?
      false
    end
  end
end
