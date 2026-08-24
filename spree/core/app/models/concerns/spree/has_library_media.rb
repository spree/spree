module Spree
  # Puts a model's named image slots in the media library.
  #
  # A file uploaded straight to a category's image slot used to exist only as
  # an ActiveStorage attachment — in storage but invisible to the library: no
  # grid entry, no search, no reuse. Declaring the slots here keeps them
  # reconciled with real +Spree::Media+ placements (+viewable+ = this record)
  # sharing the slot blobs, so the library sees what the merchant uploaded and
  # can hand the file to anything else.
  #
  # The named attachments remain the operational storage every serializer and
  # storefront reads; the placements are the library's view of them. Clearing
  # or replacing a slot UNPLACES its row — back to the library pool — rather
  # than destroying it, because the merchant's file outliving one use is the
  # point of having a library.
  #
  #   include Spree::HasLibraryMedia
  #   has_library_media :image, :square_image
  #
  # Until a real gallery arrives for these models, reconciliation owns every
  # placement on the record: a row whose blob no slot holds is unplaced. A
  # future gallery replaces the slots as the source of truth and this concern
  # dissolves into it.
  module HasLibraryMedia
    extend ActiveSupport::Concern

    included do
      # nullify, not destroy: deleting the record returns its files to the
      # library instead of taking them along.
      has_many :media, class_name: 'Spree::Media', as: :viewable, dependent: :nullify

      class_attribute :library_media_slots, instance_writer: false, default: [].freeze

      before_save :note_library_media_changes
      after_commit :sync_changed_library_media, on: %i[create update]
    end

    class_methods do
      # Declares which attachment slots live in the library.
      #
      # @param slots [Array<Symbol>] attachment names, e.g. +:image+
      # @return [void]
      def has_library_media(*slots)
        self.library_media_slots = (library_media_slots | slots.map(&:to_s)).freeze
      end
    end

    # Reconciles this record's placements against its slots: a slot blob with
    # no placement gains one, a placement whose blob no slot holds is
    # unplaced. Runs on save when a slot changed; callable directly for
    # backfills.
    #
    # @return [void]
    def sync_library_media!
      desired_blobs = library_media_slots.each_with_object({}) do |slot, blobs|
        attachment = public_send(slot)
        blobs[attachment.blob.id] ||= attachment.blob if attachment.attached?
      end

      media.includes(attachment_attachment: :blob).each do |placement|
        blob_id = placement.attachment_blob&.id
        next if blob_id && desired_blobs.delete(blob_id)

        placement.update!(viewable: nil)
      end

      desired_blobs.each_value do |blob|
        placement = Spree::Media.new(viewable: self, alt: blob.filename.to_s)
        placement.attachment.attach(blob)
        placement.save!
      end
    end

    private

    # Attachment changes are consumed by the save, so whether a slot moved has
    # to be noted before it and acted on after commit — reconciling on every
    # save would tax frequent slot-less writes like category repositioning.
    def note_library_media_changes
      @library_media_slots_changed ||= library_media_slots.any? do |slot|
        attachment_changes.key?(slot)
      end

      true
    end

    def sync_changed_library_media
      return unless @library_media_slots_changed

      @library_media_slots_changed = false
      sync_library_media!
    end
  end
end
