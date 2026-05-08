module Spree
  class Asset < Spree.base_class
    has_prefix_id :media

    include Support::ActiveStorage
    include Rails.application.routes.url_helpers
    include Spree::ImageMethods # legacy, will be removed in Spree 6
    include Spree::Metafields
    include Spree::Metadata

    # Legacy styles support (was in Spree::Image::Configuration::ActiveStorage)
    # @deprecated Will be removed in Spree 6
    def self.styles
      @styles ||= Spree::Config.product_image_variant_sizes.transform_values do |dimensions|
        "#{dimensions[0]}x#{dimensions[1]}>"
      end
    end

    def default_style
      :small
    end

    publishes_lifecycle_events

    EXTERNAL_URL_METAFIELD_KEY = 'external.url'
    MEDIA_TYPES = %w[image video external_video].freeze

    after_initialize { self.media_type ||= 'image' }

    belongs_to :viewable, polymorphic: true, touch: true
    has_many :variant_media, class_name: 'Spree::VariantMedia', foreign_key: :media_id,
             dependent: :destroy, inverse_of: :asset
    has_many :variants, through: :variant_media, source: :variant, class_name: 'Spree::Variant'
    acts_as_list scope: [:viewable_id, :viewable_type]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, :variation, to: :attachment

    validates :media_type, inclusion: { in: MEDIA_TYPES }
    validates :attachment, attached: true, content_type: Rails.application.config.active_storage.web_image_content_types,
              if: -> { media_type == 'image' }
    validates :external_video_url, presence: true, if: -> { media_type.in?(%w[video external_video]) }

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

    # STI was disabled in Spree::Image, keep it disabled here
    self.inheritance_column = nil

    store_accessor :private_metadata, :session_uploaded_assets_uuid
    scope :with_session_uploaded_assets_uuid, lambda { |uuid|
      where(session_id: uuid)
    }
    scope :with_external_url, ->(url) { url.present? ? with_metafield_key_value(EXTERNAL_URL_METAFIELD_KEY, url.strip) : none }

    # Callbacks merged from Spree::Image
    after_commit :touch_product_variants, if: :should_touch_product_variants?, on: :update
    after_commit :update_viewable_thumbnail_on_create, on: :create
    after_commit :update_viewable_thumbnail_on_destroy, on: :destroy
    after_commit :update_viewable_thumbnail_on_reorder, on: :update, if: :saved_change_to_position?
    after_commit :update_viewable_thumbnail_on_viewable_change, on: :update, if: :saved_change_to_viewable_id?

    after_create :increment_viewable_media_count
    after_destroy :decrement_viewable_media_count

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
      get_metafield(EXTERNAL_URL_METAFIELD_KEY)&.value
    end

    def external_url=(url)
      set_metafield(EXTERNAL_URL_METAFIELD_KEY, url.strip)
    end

    def skip_import?
      false
    end

    def event_prefix
      'media'
    end

    # @deprecated
    def styles
      Spree::Deprecation.warn("Asset#styles is deprecated and will be removed in Spree 6.0. Please use active storage variants with cdn_image_url")

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
      product = viewable.is_a?(Spree::Product) ? viewable : viewable.product
      product.variants.touch_all
    end

    def should_touch_product_variants?
      return false unless saved_change_to_position?

      case viewable
      when Spree::Product
        true
      when Spree::Variant
        viewable.is_master? && viewable.product.has_variants?
      else
        false
      end
    end

    def increment_viewable_media_count
      case viewable_type
      when 'Spree::Variant'
        Spree::Variant.increment_counter(:media_count, viewable_id)
        Spree::Product.increment_counter(:media_count, viewable.product_id)
      when 'Spree::Product'
        Spree::Product.increment_counter(:media_count, viewable_id)
      end
    end

    def decrement_viewable_media_count
      case viewable_type
      when 'Spree::Variant'
        Spree::Variant.decrement_counter(:media_count, viewable_id)
        Spree::Product.decrement_counter(:media_count, viewable.product_id)
      when 'Spree::Product'
        Spree::Product.decrement_counter(:media_count, viewable_id)
      end
    end

    def update_viewable_thumbnail
      case viewable_type
      when 'Spree::Variant'
        viewable.update_thumbnail!
        viewable.product.update_thumbnail!
      when 'Spree::Product'
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
