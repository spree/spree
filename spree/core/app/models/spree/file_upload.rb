module Spree
  # A file sent to `POST /files` (docs/plans/6.0-uploads-and-file-ownership.md),
  # before anything uses it.
  #
  # Two ways in, one result. A presigned upload carries only the file's
  # metadata and gets back a storage target the client sends the bytes to; a
  # multipart upload carries the bytes, which are stored here. Either way the
  # result is a blob owned by +store+ and an expiring, opaque `signed_id` the
  # client passes to whichever endpoint uses the file.
  #
  # Never persisted: the blob is the record.
  class FileUpload
    include ActiveModel::Model
    include ActiveModel::Attributes

    VISIBILITIES = %w[public private].freeze

    attribute :filename, :string
    attribute :content_type, :string
    attribute :byte_size, :integer
    attribute :checksum, :string
    attribute :visibility, :string, default: 'public'
    # The bytes of a multipart upload (an uploaded file or any IO).
    attribute :file
    attribute :store
    # Narrower limits for a caller with its own rules (a buyer's purchase
    # order document); the installation-wide ones apply otherwise.
    attribute :max_byte_size, :integer
    attribute :allowed_content_types

    attr_reader :blob, :signed_id, :expires_at

    validates :store, presence: true
    validates :visibility, inclusion: { in: VISIBILITIES }
    validates :filename, :content_type, presence: true
    validates :checksum, presence: true, unless: :multipart?
    validates :byte_size, numericality: { only_integer: true, greater_than: 0 }
    validate :byte_size_within_limit
    validate :content_type_allowed

    # The content types a public upload may have. Private uploads accept any
    # type: digital products are ebooks, archives and audio, and each
    # attachment validates its own file.
    #
    # @return [Array<String>]
    def self.public_content_types
      Rails.application.config.active_storage.web_image_content_types +
        Spree::Config.video_content_types +
        %w[text/csv]
    end

    # @return [Boolean] whether the bytes travel in the request
    def multipart?
      file.present?
    end

    # @return [Boolean] whether the file lands on private storage
    def private?
      visibility == 'private'
    end

    # Validates and creates the blob. A multipart upload is stored here; a
    # presigned one waits for the client to send its bytes to {#upload_target}.
    #
    # @return [Boolean]
    def save
      read_file_facts if multipart?
      return false unless valid?

      @blob = multipart? ? store_bytes : reserve_blob
      @expires_at = Spree::Uploads::SIGNED_ID_EXPIRY.from_now
      @signed_id = Spree::Uploads.signed_id_for(@blob)
      true
    end

    # Where a presigned upload's bytes go, or nil once the file is stored.
    #
    # @return [Spree::FileUpload::Target, nil]
    def upload_target
      return if multipart? || blob.nil?

      Target.new(
        http_method: 'PUT',
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      )
    end

    # The storage target a presigned upload sends its bytes to.
    class Target
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Not `method`, which every Ruby object already answers.
      attribute :http_method, :string
      attribute :url, :string
      attribute :headers
    end

    private

    # The size and type of a multipart upload come from the bytes, never from
    # what the client declared: Marcel reads the content, so a renamed
    # executable is not accepted as an image.
    def read_file_facts
      io = file.respond_to?(:to_io) ? file.to_io : file
      self.filename = filename.presence || file.try(:original_filename)
      self.byte_size = io.size
      self.content_type = Marcel::MimeType.for(io, name: filename, declared_type: content_type.presence || file.try(:content_type))
      io.rewind
    end

    def reserve_blob
      ActiveStorage::Blob.create!(
        filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type,
        service_name: service_name, store_id: store.id
      )
    end

    def store_bytes
      io = file.respond_to?(:to_io) ? file.to_io : file
      ActiveStorage::Blob.build_after_unfurling(
        io: io, filename: filename, content_type: content_type, service_name: service_name, identify: false
      ).tap do |blob|
        blob.store_id = store.id
        blob.save!
        blob.upload_without_unfurling(io)
      end
    end

    def service_name
      private? ? Spree.private_storage_service_name : Spree.public_storage_service_name
    end

    def size_limit
      max_byte_size || (multipart? ? Spree::Config.max_multipart_upload_size : Spree::Config.max_upload_size)
    end

    def byte_size_within_limit
      return if byte_size.nil? || byte_size <= size_limit

      errors.add(:byte_size, :less_than_or_equal_to, count: ActiveSupport::NumberHelper.number_to_human_size(size_limit))
    end

    def content_type_allowed
      allowed = allowed_content_types || (self.class.public_content_types unless private?)
      return if allowed.nil? || content_type.blank? || allowed.include?(content_type)

      errors.add(:content_type, :inclusion, value: content_type)
    end
  end
end
