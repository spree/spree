module Spree
  # Merchandising media for commerce entities — product photography, variant
  # shots, product video. Renamed from Spree::Asset in 6.0; Spree::Asset stays
  # readable as a deprecated alias for one release.
  class Media < Spree.base_class
    has_prefix_id :media

    include Rails.application.routes.url_helpers
    include Spree::HasCustomFields
    include Spree::Metadata
    # Media is store-owned rather than reaching its store through the viewable:
    # a library upload has no viewable until someone places it, so there is
    # nothing to derive tenancy from. The column stays nullable for rows the
    # upgrade could not reach; new rows always carry a store.
    include Spree::SingleStoreResource
    include Spree::HasExternalReferences

    # SingleStoreResource refuses any store change on a persisted record. Media
    # predates its store column, so a legacy row carries nil until the upgrade
    # task fills it in — and between db:migrate and that task, every edit of an
    # existing row would otherwise fail validation. Adopting a store is not
    # changing one.
    def ensure_store_association_is_not_changed
      return if store_id_was.nil?

      super
    end

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

    belongs_to :viewable, polymorphic: true, touch: true, optional: true
    has_many :variant_media, class_name: 'Spree::VariantMedia', foreign_key: :media_id,
             dependent: :destroy, inverse_of: :asset
    has_many :variants, through: :variant_media, source: :variant, class_name: 'Spree::Variant'
    # store_id is in the scope for the library's sake: an unplaced row has no
    # viewable, so without it every store's uploads would share one list and
    # their positions would bleed across tenants.
    acts_as_list scope: [:store_id, :viewable_id, :viewable_type]

    # Whether this row is in use, or sitting in the library waiting to be
    # placed. Not a flag — an unplaced row simply has no viewable.
    scope :attached, -> { where.not(viewable_id: nil) }
    scope :unattached, -> { where(viewable_id: nil) }

    # Filename search for the library. The name lives on the blob rather than
    # on this row, so it is a join rather than a column match.
    scope :filename_cont, lambda { |term|
      next all if term.blank?

      joins(attachment_attachment: :blob)
        .where(ActiveStorage::Blob.arel_table[:filename].matches("%#{term}%"))
    }

    # One row per file, for the library — which shows files, not placements.
    #
    # Reuse shares a blob across rows, so a file placed on three products is
    # three rows of the same picture; listing them all reads as three copies a
    # merchant then has to tell apart. The newest row of each blob stands in,
    # and its `usage` lists everywhere the file actually appears.
    #
    # Rows with no attachment at all (an external video) have no blob to group
    # by and are always kept.
    # Grouped over the rows this scope already covers, not over every store's:
    # a global winner can belong to another tenant, which hid the file from the
    # library that owns it — not listed, not searchable, not deletable.
    scope :distinct_by_file, lambda {
      attachments = ActiveStorage::Attachment.arel_table
      newest_per_blob = ActiveStorage::Attachment
                          .where(record_type: name, name: 'attachment')
                          .where(record_id: unscope(:order).select(:id))
                          .group(:blob_id)
                          .select(attachments[:record_id].maximum)

      where(
        arel_table[:id].in(Arel.sql(newest_per_blob.to_sql)).
          or(arel_table[:media_type].eq('external_video'))
      )
    }

    self.whitelisted_ransackable_attributes = %w[alt media_type created_at updated_at]
    self.whitelisted_ransackable_scopes = %w[attached unattached filename_cont]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, :variation, to: :attachment

    validates :media_type, inclusion: { in: MEDIA_TYPES }
    # Registered in Spree.media_viewable_types — an extension placing media on
    # its own model appends there rather than editing this list.
    validates :viewable_type, inclusion: { in: -> (_record) { Spree.media_viewable_types } },
              allow_nil: true
    validates :attachment, attached: true, content_type: Rails.application.config.active_storage.web_image_content_types,
              if: :image?
    validates :attachment, attached: true, content_type: ->(_record) { Spree::Config.video_content_types },
              size: { less_than_or_equal_to: ->(_record) { Spree::Config.max_video_upload_size } },
              if: :video?
    validates :poster, content_type: Rails.application.config.active_storage.web_image_content_types,
              if: -> { poster.attached? }
    validates :external_video_url, presence: true, if: :external_video?
    validate :external_video_url_is_supported, if: -> { external_video? && external_video_url.present? }
    validate :poster_signed_id_is_resolvable, if: -> { @poster_signed_id.present? }

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

      # Rich text embeds: bounded, never cropped, so the merchant's chosen
      # aspect ratio survives. Not preprocessed — most files are never embedded
      # in a description, so this is generated on first use instead of on every
      # upload.
      attachable.variant :embed,
                         format: "webp",
                         resize_to_limit: Spree::Config.rich_text_image_size,
                         saver: WEBP_SAVER_OPTIONS
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
    after_commit :update_viewable_thumbnail_on_viewable_change, on: :update, if: :saved_change_to_viewable?

    after_save :apply_poster_signed_id, if: -> { defined?(@poster_signed_id) }
    after_create :increment_viewable_media_count
    after_destroy :decrement_viewable_media_count
    after_update :move_viewable_media_count, if: :saved_change_to_viewable?

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
    #
    # The attach is deferred to after_save: attaching on assignment uploads the
    # blob even when the record then fails validation, orphaning it. A blank
    # value removes the poster, so a merchant can undo a wrong one.
    def poster_signed_id=(signed_id)
      @poster_signed_id = signed_id
    end

    attr_reader :poster_signed_id

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

    # Whether this row can stand in as a thumbnail. A video qualifies only once
    # it has a still — otherwise a gallery's first tile, and every listing that
    # renders `thumbnail_url` in an <img>, would come back empty or with a raw
    # video file.
    # @return [Boolean]
    def renderable_as_image?
      still_image.present? || provider_still_url.present?
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

    # An image is given its external URL before it is saved, so `store_id` is
    # still unset at that point. Run the callback that fills it early rather
    # than repeating how it picks the owner.
    def custom_field_definition_store
      ensure_store unless store_id?
      store || Spree::Current.store
    end

    # Places a copy of this file on another product or variant, sharing the
    # blob rather than copying the file. The copy is an ordinary new row, so it
    # carries its own position, variant links and list placement in the new
    # context, and every callback (counter caches, thumbnails) fires normally.
    #
    # Nothing is written to storage: both records point at the same blob, and
    # the already-generated renditions are keyed on that blob, so a reused file
    # needs no reprocessing either. Deleting one copy leaves the file intact —
    # the foreign key from active_storage_attachments blocks purging a blob
    # another attachment still references, and ActiveStorage::PurgeJob discards
    # on exactly that violation.
    #
    # The copy belongs to whichever store owns its new home, not to the store
    # the source came from — media follows the thing it is a picture of.
    #
    # @param viewable [Spree::Product, Spree::Variant, Spree::Category, Spree::Collection, nil]
    #   the new owner, or nil for an unplaced library copy
    # @return [Spree::Media] an unsaved copy
    def duplicate_for(viewable)
      copy = self.class.new(
        viewable: viewable,
        media_type: media_type,
        alt: alt,
        external_video_url: external_video_url,
        focal_point_x: focal_point_x,
        focal_point_y: focal_point_y
      )

      copy.attachment.attach(attachment.blob) if attachment.attached?
      copy.poster.attach(poster.blob) if poster.attached?
      copy
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

    protected

    # A placed row belongs to whichever store owns its home — the category's
    # own store, or the product's for a variant — whichever store the request
    # is for: media follows the thing it is a picture of. A library upload has
    # no viewable yet, so it falls back to the concern's current-store default.
    def ensure_store
      # An unregistered viewable_type raises on load rather than reaching the
      # inclusion validation, which is the thing that should reject it.
      self.store_id = viewable.try(:store_id) || product&.store_id
      super unless store_id?
    rescue NameError
      super
    end

    private

    def apply_poster_signed_id
      signed_id = @poster_signed_id
      remove_instance_variable(:@poster_signed_id)

      if signed_id.present?
        poster.attach(signed_id)
      elsif poster.attached?
        # purge_later, not detach — detach leaves the blob behind in storage.
        poster.purge_later
      end
    end

    # A tampered or expired signed id raises deep inside `attach`, which would
    # surface as a 500 after the row is already written. Resolve it up front so
    # a bad one reads as a validation error on the field that carried it.
    def poster_signed_id_is_resolvable
      ActiveStorage::Blob.find_signed!(@poster_signed_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      errors.add(:poster, :invalid)
    end

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

    # A row that changes owner has already been counted against the old one.
    # Without this the previous owner stays inflated and the new one short.
    def move_viewable_media_count
      adjust_media_count(*previous_owner, -1)
      increment_viewable_media_count
    end

    # A move changes viewable_type, viewable_id, or both — read whichever
    # actually changed, falling back to the current value for the other.
    # @return [Array(String, Integer)] the owner this row was taken from
    def previous_owner
      [
        saved_change_to_viewable_type&.first || viewable_type,
        saved_change_to_viewable_id&.first || viewable_id
      ]
    end

    def saved_change_to_viewable?
      saved_change_to_viewable_id? || saved_change_to_viewable_type?
    end

    def adjust_media_count(type, id, by)
      return if id.blank?

      case type
      when 'Spree::Variant'
        variant = Spree::Variant.find_by(id: id) || return
        Spree::Variant.update_counters(id, media_count: by)
        Spree::Product.update_counters(variant.product_id, media_count: by)
      when 'Spree::Product'
        Spree::Product.update_counters(id, media_count: by) if Spree::Product.exists?(id: id)
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

    # On a move, the owner left behind still points at this row through its
    # primary_media_id — refresh it too, or it renders media it no longer has.
    def update_viewable_thumbnail_on_viewable_change
      type, id = previous_owner
      previous = type&.safe_constantize&.find_by(id: id)

      case previous
      when Spree::Variant
        previous.update_thumbnail!
        previous.product&.update_thumbnail!
      when Spree::Product
        previous.update_thumbnail!
      end

      update_viewable_thumbnail
    end

    alias update_viewable_thumbnail_on_create update_viewable_thumbnail
    alias update_viewable_thumbnail_on_destroy update_viewable_thumbnail
    alias update_viewable_thumbnail_on_reorder update_viewable_thumbnail
  end
end
