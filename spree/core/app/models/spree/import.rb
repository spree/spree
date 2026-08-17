require 'csv'

module Spree
  class Import < Spree.base_class
    has_prefix_id :imp

    include Spree::NumberIdentifier
    has_spree_number prefix: 'IM'

    # Where the downloadable example CSVs are served from — see `sample_csv_url`.
    #
    # Pinned to the installed version's tag rather than `main`: whether a type
    # *has* an example is answered by the local `db/sample_data`, so pointing
    # elsewhere would let a released install link to a newer, incompatible
    # schema (or a file that has since been removed).
    SAMPLE_DATA_BASE_URL_TEMPLATE =
      'https://raw.githubusercontent.com/spree/spree/refs/tags/v%<version>s/spree/core/db/sample_data'.freeze

    publishes_lifecycle_events

    # Set event prefix for all Import subclasses
    # This ensures Spree::Imports::Products publishes 'import.create' not 'products.create'
    self.event_prefix = 'import'

    #
    # Associations
    #
    belongs_to :owner, polymorphic: true # Store, Seller, etc.
    belongs_to :user, class_name: Spree.admin_user_class.to_s, optional: true
    has_many :mappings, class_name: 'Spree::ImportMapping', dependent: :destroy, inverse_of: :import
    alias import_mappings mappings
    has_many :rows, class_name: 'Spree::ImportRow', dependent: :destroy_async, inverse_of: :import
    alias import_rows rows

    #
    # Validations
    #
    validates :owner, :user, :type, presence: true
    validates :attachment, presence: true, unless: -> { Rails.env.test? }
    validate :ensure_whitelisted_type
    validate :ensure_attachment_content_type

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[number type status]

    #
    # Scopes
    #
    scope :for_store, ->(store) { where(owner: store) }

    #
    # Attachments
    #
    has_one_attached :attachment, service: Spree.private_storage_service_name

    #
    # State machine
    #
    state_machine initial: :pending, attribute: :status do
      event :start_mapping do
        transition to: :mapping
      end
      before_transition to: :mapping, do: :create_mappings

      event :complete_mapping do
        transition from: :mapping, to: :completed_mapping
      end
      after_transition to: :completed_mapping, do: :create_rows_async

      event :start_processing do
        transition from: :completed_mapping, to: :processing
      end

      event :complete do
        transition from: :processing, to: :completed
      end
      after_transition to: :completed, do: :touch_store
      after_transition to: :completed, do: :publish_import_completed_event

      event :fail do
        transition to: :failed
      end

      # Re-processes rows that failed: the dispatcher targets pending_and_failed
      # rows, so retry is just a transition + re-dispatch.
      event :retry_failed_rows do
        transition from: :completed, to: :processing, if: ->(import) { import.rows.failed.exists? }
      end
      after_transition on: :retry_failed_rows, do: :process_rows_async
    end

    #
    # Preferences
    #
    preference :delimiter, :string, default: ','
    # Run the pipeline in-process instead of enqueuing it. For rake tasks, seeds
    # and the console, where the caller needs the data to exist when the call
    # returns and there may be no worker attached. Never set it from a request:
    # a large CSV blocks for minutes.
    #
    # A preference, not a virtual attribute, so it survives the `Import.find`
    # each processing job does — otherwise every job would have to take (and
    # forward) an `inline:` argument.
    preference :inline, :boolean, default: false
    # Suppress the events the *rows* publish — a `product.created` per imported
    # product, plus `import_row.*`. The import's own `import.*` events still
    # fire: a handful per import is useful, thousands from a seeded catalog are
    # not.
    #
    # For seeding demo or sample data, where subscribers would otherwise deliver
    # webhooks and analytics for a catalog nobody actually created. A preference
    # rather than a virtual attribute because the processing jobs each reload
    # the record, so it has to outlive the enqueue. Independent of `inline`: a
    # background import can still be silent, and an inline one observed.
    preference :skip_events, :boolean, default: false
    # Absolute URL of the dashboard's imports view, captured at create and
    # validated against the store's allowed origins — the import-done email
    # links back to it. Blank for legacy-admin or app-created imports.
    preference :results_url, :string, default: nil

    # Publicly downloadable example CSV for this import's type, or nil when the
    # type has no sample file. Resolved from the `type` column rather than the
    # instance's class, so it works on a record built as the base
    # `Spree::Import` with `type` assigned (which is how the admin's new-import
    # form builds it).
    #
    # @return [String, nil]
    def sample_csv_url
      self.class.available_types.find { |klass| klass.to_s == type.to_s }&.sample_csv_url
    end

    # Header-only CSV for this import's schema — the blank counterpart to
    # `sample_csv_url`. One line, so callers can inline it (e.g. as a `data:`
    # URI) instead of round-tripping to the server for it.
    #
    # @return [String]
    def template_csv
      ::CSV.generate_line(schema_fields.map { |field| field[:name] })
    end

    # Suggested filename for `template_csv`, e.g. "products_import_template.csv".
    #
    # @return [String]
    def template_csv_filename
      "#{self.class.api_type_for(type)}_import_template.csv"
    end

    # Returns true if the import has more rows than the large import threshold.
    # Large imports skip per-row UI broadcasts and use bulk processing.
    # @return [Boolean]
    def large_import?
      rows_count >= Spree::Config[:large_import_threshold]
    end

    # Returns the schema field name used to group rows for parallel processing.
    # Rows sharing the same value in this field are processed together in one job.
    # Returns nil for imports where rows are independent (default — batched in chunks).
    # @return [String, nil]
    def group_column
      nil
    end

    # Returns true if the import is in mapping state
    # @return [Boolean]
    def mapping?
      status == 'mapping'
    end

    # Returns true if the import is processing or completed mapping
    # @return [Boolean]
    def processing?
      ['processing', 'completed_mapping'].include?(status)
    end

    # Returns true if the import is complete
    # @return [Boolean]
    def complete?
      status == 'completed'
    end

    # Imports are deletable only while no processing jobs can be in flight —
    # ProcessJob/ProcessGroupJob re-load the record mid-run.
    # @return [Boolean]
    def can_be_deleted?
      %w[pending mapping completed failed].include?(status)
    end

    # Per-status row counts for API status payloads, memoized so one request
    # issues a single grouped COUNT instead of one per status.
    # @return [Hash{String => Integer}]
    def rows_status_counts
      @rows_status_counts ||= rows.group(:status).count
    end

    # Public API name for the +results_url+ preference (read/write symmetry).
    # String preferences round-trip nil as "" — normalize blank to nil.
    def results_url
      preferred_results_url.presence
    end

    def results_url=(value)
      self.preferred_results_url = value
    end

    # URL of the wizard/results view for this import — the caller-provided
    # +results_url+ with the wizard's `?import=` param appended (a no-op for
    # the legacy admin's show URL, whose path already identifies the import).
    # Nil when the preference is absent; the mailer then renders no link.
    # @return [String, nil]
    def results_page_url
      return if preferred_results_url.blank?

      uri = URI.parse(preferred_results_url)
      params = URI.decode_www_form(uri.query.to_s)
      params << ['import', prefixed_id]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    # First data row as { header => value }, reading a single line of the
    # attached CSV — used by the mapping UI to show example values.
    # @return [Hash]
    def sample_row
      return {} if attachment_file_content.blank?

      row = ::CSV.foreach(StringIO.new(attachment_file_content), headers: true, col_sep: preferred_delimiter).first
      row&.to_h || {}
    rescue ::CSV::MalformedCSVError, EncodingError
      {}
    end

    # Returns the model class for the import
    # @return [Class]
    def model_class
      if type == 'Spree::Imports::Customers'
        Spree.customer_class
      else
        "Spree::#{type.demodulize.singularize}".safe_constantize
      end
    end

    # Returns the import schema for the import
    # @return [Spree::ImportSchema]
    def import_schema
      "Spree::ImportSchemas::#{type.demodulize}".safe_constantize.new
    end

    # Returns the row processor class for the import
    # @return [Class]
    def row_processor_class
      "Spree::ImportRowProcessors::#{type.demodulize.singularize}".safe_constantize
    end

    # Returns the fields for the import schema
    # If model supports custom_fields, it will include the custom_field definitions for this model
    # @return [Array<Hash>]
    def schema_fields
      base_fields = import_schema.fields

      # Dynamically add custom_field definitions if the model supports custom_fields
      if model_class_supports_custom_fields?
        custom_field_fields = custom_field_definitions_for_model.map do |definition|
          {
            name: definition.csv_header_name,
            label: definition.label
          }
        end
        base_fields + custom_field_fields
      else
        base_fields
      end
    end

    # Returns the file columns that are not mapped
    # @return [Array<String>]
    def unmapped_file_columns
      csv_headers.reject { |header| mappings.mapped.exists?(file_column: header) }
    end

    # Returns the required fields for the import schema
    # @return [Array<String>]
    def required_fields
      import_schema.required_fields
    end

    # Returns the mapped fields for the import schema
    # @return [Array<String>]
    def mapped_fields
      @mapped_fields ||= mappings.mapped.where(schema_field: required_fields)
    end

    # Returns true if the mapping is done
    # @return [Boolean]
    def mapping_done?
      mapped_fields.count == required_fields.count
    end

    # Returns the display name for the import
    # @return [String]
    def display_name
      "#{Spree.t(type.demodulize.pluralize.downcase)} #{number}"
    end

    def touch_store
      store.touch
    end

    def publish_import_completed_event
      publish_event('import.completed')
    end

    # Returns the headers of the csv file
    # @return [Array<String>]
    def csv_headers
      return [] if attachment_file_content.blank?

      @csv_headers ||= ::CSV.parse_line(
        attachment_file_content,
        col_sep: preferred_delimiter
      )
    end

    # Returns the content of the attachment file
    # @return [String]
    def attachment_file_content
      @attachment_file_content ||= attachment.attached? ? attachment.blob.download&.force_encoding('UTF-8') : nil
    end

    # Creates mappings from the schema fields
    # TODO: get mappings from the previous import if it exists, so user won't have to map the same columns again
    def create_mappings
      schema_fields.each do |schema_field|
        mapping = mappings.find_or_create_by!(schema_field: schema_field[:name])
        mapping.try_to_auto_assign_file_column(csv_headers)
        mapping.save!
      end
    end

    # Creates rows asynchronously
    # @return [void]
    def create_rows_async
      if preferred_inline
        # The transition callback runs inside the state machine's
        # transaction and Continuations forbid checkpoints there — the
        # inline run starts at commit, still before the transition call
        # returns to the caller.
        ActiveRecord.after_all_transactions_commit { Spree::Imports::ProcessJob.perform_now(id) }
        return
      end

      # The 2s delay lets the attachment settle before the job reads it.
      Spree::Imports::ProcessJob.set(wait: 2.seconds).perform_later(id)
    end

    # Processes rows asynchronously
    # @return [void]
    def process_rows_async
      if preferred_inline
        ActiveRecord.after_all_transactions_commit { Spree::Imports::ProcessJob.perform_now(id, skip_row_creation: true) }
        return
      end

      Spree::Imports::ProcessJob.perform_later(id, skip_row_creation: true)
    end

    # Returns the store for the import
    # @return [Spree::Store]
    def store
      if owner.is_a?(Spree::Store)
        owner
      else
        owner.respond_to?(:store) ? owner.store : Spree::Store.default
      end
    end

    # Returns the current ability for the import
    # @return [Spree::Ability]
    def current_ability
      @current_ability ||= Spree.ability_class.new(user, { store: store })
    end

    # Per-instance cache shared by row processors within a single processing job.
    # Group jobs funnel every row through the same Import instance, so lookups of
    # shared records (tax/shipping categories, option types, custom_field definitions)
    # resolve once per job instead of once per row.
    # @return [Hash]
    def row_lookup_cache
      @row_lookup_cache ||= {}
    end

    def event_serializer_class
      'Spree::Api::V3::ImportSerializer'.safe_constantize
    end

    class << self
      # Returns the available types for the import
      # @return [Array<Class>]
      def available_types
        Spree.import_types
      end

      # Returns the available models for the import
      # @return [Array<Class>]
      def available_models
        available_types.map(&:model_class)
      end

      # Returns the type for the model
      # @return [Class]
      def type_for_model(model)
        available_types.find { |type| type.model_class.to_s == model.to_s }
      end

      # Admin API scope family gating this import type — an import is a bulk
      # write, so an API key needs `write_<required_scope>` to create and
      # manage it. Derived from the class name (Spree::Imports::Customers =>
      # :customers); override in subclasses gated by a different scope.
      # Returns nil on the base class, so unmapped types are only accessible
      # to write_all keys.
      #
      # @return [Symbol, nil]
      def required_scope
        return nil if self == Spree::Import

        to_s.demodulize.underscore.to_sym
      end

      # Publicly downloadable example CSV for this import type — the same file
      # `rake spree:load_sample_data` feeds through this very pipeline, so it is
      # a working example rather than a hand-maintained sample that can drift
      # from the schema.
      #
      # Whether a type *has* an example is answered by `db/sample_data` itself,
      # so adding or removing a CSV there needs no change here; a type with no
      # sample file returns nil and the UI omits the link. The URL is pinned to
      # the installed version's tag so the file served always matches the schema
      # that check was made against.
      #
      # @return [String, nil]
      def sample_csv_url
        return nil if self == Spree::Import
        return nil unless Spree::Core::Engine.root.join('db', 'sample_data', sample_csv_filename).exist?

        [sample_data_base_url, sample_csv_filename].join('/')
      end

      # @return [String]
      def sample_data_base_url
        format(SAMPLE_DATA_BASE_URL_TEMPLATE, version: Spree.version)
      end

      # eg. Spree::Imports::ProductTranslations => "product_translations.csv"
      # @return [String]
      def sample_csv_filename
        "#{api_type}.csv"
      end

      # eg. Spree::Imports::Orders => Spree::Order
      def model_class
        return Spree.customer_class if to_s == 'Spree::Imports::Customers'

        klass = "Spree::#{to_s.demodulize.singularize}".safe_constantize

        raise NameError, "Missing model class for #{self}" unless klass

        klass
      end
    end

    private

    def ensure_whitelisted_type
      return if type.blank?

      allowed = self.class.available_types.map(&:to_s)
      errors.add(:type, :inclusion) unless allowed.include?(type)
    end

    def ensure_attachment_content_type
      return if attachment.blank?

      errors.add(:attachment, :content_type) unless attachment.content_type.in?(%w[text/csv])
    end

    def model_class_supports_custom_fields?
      return false unless model_class.present?

      model_class.included_modules.include?(Spree::HasCustomFields)
    end

    def custom_field_definitions_for_model
      return [] unless model_class.present?

      Spree::CustomFieldDefinition.for_resource_type(model_class.name)
    end
  end
end
