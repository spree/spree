module Spree
  # One place a media file is in use. Ephemeral — computed by
  # +Spree::Media::Usage+ from the blob's attachment rows, never persisted.
  #
  # A file is "in use" more broadly than a media row suggests: reusing a file
  # on another product shares its blob, and so does picking it for a category
  # or store image, so the honest answer to "what breaks if I delete this"
  # comes from the blob's attachments rather than from this row's own owner.
  class MediaUsageReference
    include ActiveModel::Model
    include ActiveModel::Attributes

    # What kind of thing is using the file — 'media' for a product or variant
    # gallery row, 'attachment' for a plain image field on some other record.
    attribute :kind, :string
    # Human-facing label for the owner, e.g. the product's name.
    attribute :name, :string
    # The owning record's class name and prefixed id, so the dashboard can
    # link to it without a second lookup.
    attribute :owner_type, :string
    attribute :owner_id, :string
    # Which field on the owner holds the file ('attachment', 'image', 'logo').
    attribute :field, :string

    validates :kind, :owner_type, presence: true
  end
end
