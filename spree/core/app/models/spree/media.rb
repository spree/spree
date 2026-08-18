module Spree
  # Merchandising media for commerce entities — product photography, variant
  # shots, product video. Renamed from Spree::Asset in 6.0; Spree::Asset stays
  # readable as a deprecated alias for one release.
  class Media < Spree.base_class
    has_prefix_id :media

    include Rails.application.routes.url_helpers
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    EXTERNAL_URL_CUSTOM_FIELD_KEY = 'external.url'
    MEDIA_TYPES = %w[image video external_video].freeze

    # Domain attributes a client may write, shared by every write path — the
    # media endpoints and the inline `media:` list on a product. Each path adds
    # its own transport keys (an upload's signed id, a row id) on top. Adding a
    # field here reaches both, so it can't be dropped on the one a client uses.
    WRITABLE_ATTRIBUTES = %i[
      alt position media_type external_video_url poster_signed_id
      focal_point_x focal_point_y
    ].freeze

    after_initialize { self.media_type ||= 'image' }

    belongs_to :viewable, polymorphic: true, touch: true
    has_many :variant_media, class_name: 'Spree::VariantMedia', foreign_key: :media_id,
             dependent: :destroy, inverse_of: :asset
    has_many :variants, through: :variant_media, source: :variant, class_name: 'Spree::Variant'
    acts_as_list scope: [:viewable_id, :viewable_type]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, :variation, to: :attachment

    validates :media_type, inclusion: { in: MEDIA_TYPES }
    validates :attachment, attached: true, content_type: Rails.application.config.active_storage.web_image_content_types,
              if: :image?
    validates :attachment, attached: true, content_type: ->(_record) { Spree::Config.video_content_types },
              size: { less_than_or_equal_to: ->(_record) { Spree::Config.max_video_upload_size } },
              if: :video?
    validates :external_video_url, presence: true, if: :external_video?
    validate :external_video_url_is_supported, if: -> { external_video? && external_video_url.present? }

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

    # Still frame shown wherever a video can't play — gallery tiles, emails,
    # the admin grid. Optional: YouTube serves its own, and an uploaded video
    # without one simply renders a placeholder.
    has_one_attached :poster, service: Spree.public_storage_service_name do |attachable|
      Spree::Config.product_image_variant_sizes.each do |name, (width, height)|
        attachable.variant name,
                           format: "webp",
                           resize_to_fill: [width, height],
                           saver: WEBP_SAVER_OPTIONS,
                           preprocessed: true
      end
    end

    # Both attachments load with the row — the serializer reads the poster for
    # every video, so leaving it out costs a query per video in a listing.
    default_scope { includes(attachment_attachment: :blob, poster_attachment: :blob) }

    # `type` is a vestige of the old Spree::Image/Spree::Video STI —
    # media_type is the discriminator now. The column drops in 6.1.
    self.inheritance_column = nil

    store_accessor :metadata, :session_uploaded_assets_uuid
    scope :with_session_uploaded_assets_uuid, lambda { |uuid|
      where(session_id: uuid)
    }
    scope :with_external_url, ->(url) { url.present? ? with_custom_field_key_value(EXTERNAL_URL_CUSTOM_FIELD_KEY, url.strip) : none }

    after_commit :touch_product_variants, if: :should_touch_product_variants?, on: :update
    after_commit :update_viewable_thumbnail_on_create, on: :create
    after_commit :update_viewable_thumbnail_on_destroy, on: :destroy
    after_commit :update_viewable_thumbnail_on_reorder, on: :update, if: :saved_change_to_position?
    after_commit :update_viewable_thumbnail_on_viewable_change, on: :update, if: :saved_change_to_viewable_id?

    after_create :increment_viewable_media_count
    after_destroy :decrement_viewable_media_count

    def image?
      media_type == 'image'
    end

    def video?
      media_type == 'video'
    end

    def external_video?
      media_type == 'external_video'
    end

    # @return [Boolean] whether this row plays as video, hosted or embedded
    def playable_video?
      video? || external_video?
    end

    # Parsed form of external_video_url — provider, embed URL, watch URL.
    # @return [Spree::ExternalVideo, nil]
    def external_video
      return nil unless external_video?

      @external_video ||= Spree::ExternalVideo.parse(external_video_url)
    end

    # A plain writer so a poster rides mass-assignment like any other attribute,
    # on every write path, instead of each caller reaching for the attachment.
    def poster_signed_id=(signed_id)
      poster.attach(signed_id) if signed_id.present?
    end

    def external_video_url=(url)
      @external_video = nil
      super(url.is_a?(String) ? url.strip.presence : url)
    end

    # The one definition of "which image represents this row": an image is its
    # own attachment, a video is its poster. Nil for a video with no poster —
    # ask #provider_still_url for the provider's own thumbnail, which isn't an
    # attachment and so can't be resized.
    # @return [ActiveStorage::Attached::One, nil]
    def still_image
      source = playable_video? ? poster : attachment
      source if source.attached?
    end

    # Provider-hosted still for an external video, when nothing was uploaded.
    # @return [String, nil]
    def provider_still_url
      external_video&.thumbnail_url
    end

    def product
      @product ||= case viewable_type
                   when 'Spree::Variant' then viewable&.product
                   when 'Spree::Product' then viewable
                   end
    end

    # Accepts prefixed IDs ("variant_abc") or raw IDs from admin forms.
    # Variants from a different product are silently dropped — the security
    # boundary against form tampering.
    def variant_ids=(ids)
      return if viewable_type != 'Spree::Product' || product.blank?

      super(Spree::VariantMedia.resolve_variant_ids(product, ids || []))
    end

    def focal_point
      return nil if focal_point_x.nil? || focal_point_y.nil?

      { x: focal_point_x, y: focal_point_y }
    end

    def focal_point=(point)
      if point.nil?
        self.focal_point_x = nil
        self.focal_point_y = nil
      else
        self.focal_point_x = point[:x]
        self.focal_point_y = point[:y]
      end
    end

    def external_url
      get_custom_field(EXTERNAL_URL_CUSTOM_FIELD_KEY)&.value
    end

    def external_url=(url)
      set_custom_field(EXTERNAL_URL_CUSTOM_FIELD_KEY, url.strip)
    end

    def skip_import?
      false
    end

    def event_prefix
      'media'
    end

    # Convention would resolve MediaSerializer — the full customer-facing
    # payload with every image size. Events carry the lean shape instead.
    def event_serializer_class
      'Spree::Api::V3::MediaEventSerializer'.safe_constantize
    end

    private

    def external_video_url_is_supported
      return if Spree::ExternalVideo.supported?(external_video_url)

      errors.add(:external_video_url, :unsupported_video_provider)
    end

    def touch_product_variants
      product = viewable.is_a?(Spree::Product) ? viewable : viewable.product
      product.variants.touch_all
    end

    def should_touch_product_variants?
      return false unless saved_change_to_position?

      # Variants fall back to product-level media, so only reordering a
      # product-level asset changes what the variants display.
      viewable.is_a?(Spree::Product)
    end

    def increment_viewable_media_count
      case viewable
      when Spree::Variant
        Spree::Variant.increment_counter(:media_count, viewable_id)
        Spree::Product.increment_counter(:media_count, viewable.product_id)
      when Spree::Product
        Spree::Product.increment_counter(:media_count, viewable_id)
      end
    end

    def decrement_viewable_media_count
      case viewable
      when Spree::Variant
        Spree::Variant.decrement_counter(:media_count, viewable_id)
        Spree::Product.decrement_counter(:media_count, viewable.product_id)
      when Spree::Product
        Spree::Product.decrement_counter(:media_count, viewable_id)
      end
    end

    def update_viewable_thumbnail
      case viewable
      when Spree::Variant
        viewable.update_thumbnail!
        viewable.product.update_thumbnail!
      when Spree::Product
        viewable.update_thumbnail!
        # Linked variants resolve their own thumbnail through gallery_media,
        # which sorts by this asset's product-level position. Reorders or
        # destroys here can change a linked variant's first asset.
        variants.find_each(&:update_thumbnail!)
      end
    end

    alias update_viewable_thumbnail_on_create update_viewable_thumbnail
    alias update_viewable_thumbnail_on_destroy update_viewable_thumbnail
    alias update_viewable_thumbnail_on_reorder update_viewable_thumbnail
    alias update_viewable_thumbnail_on_viewable_change update_viewable_thumbnail
  end
end
