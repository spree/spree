module Spree
  class ImportRow < Spree.base_class
    has_prefix_id :imrow

    # Set event prefix for ImportRow
    self.event_prefix = 'import_row'

    #
    # Associations
    #
    belongs_to :import, class_name: 'Spree::Import', counter_cache: :rows_count
    belongs_to :item, polymorphic: true, optional: true # eg. Spree::Variant, Spree::Order, etc.
    delegate :store, to: :import

    #
    # Validations
    #
    validates :import, :data, presence: true
    validates :row_number, uniqueness: { scope: :import_id }, numericality: { only_integer: true, greater_than: 0 }, presence: true

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[status row_number]

    #
    # State machine
    #
    state_machine initial: :pending, attribute: :status do
      event :start_processing do
        transition to: :processing
      end

      event :fail do
        transition to: :failed
      end
      after_transition to: :failed, do: :publish_import_row_failed_event
      # NOTE: add_row_to_import_view and update_footer_in_import_view
      # are now handled by Spree::Admin::ImportRowSubscriber

      event :complete do
        transition to: :completed
      end
      after_transition to: :completed, do: :publish_import_row_completed_event
      # NOTE: add_row_to_import_view and update_footer_in_import_view
      # are now handled by Spree::Admin::ImportRowSubscriber
    end

    # How long a row may sit in `processing` before we consider its owning worker dead
    # (OOM, SIGKILL, deploy without graceful drain — none of these trigger a Sidekiq
    # retry). After this window, stalled rows no longer block the import from completing.
    STALLED_PROCESSING_AFTER = 1.hour

    #
    # Scopes
    #
    scope :pending_and_failed, -> { where(status: %i[pending failed]) }
    scope :completed, -> { where(status: :completed) }
    scope :failed, -> { where(status: :failed) }
    scope :processed, -> { where(status: %i[completed failed]) }
    # Rows still legitimately blocking import completion: `pending` (not started) or
    # `processing` with a recent updated_at (worker still alive). Orphaned `processing`
    # rows past the stall window are excluded so a dead worker can't permanently block
    # completion — operators can clean those up separately.
    scope :in_flight, -> {
      where(status: :pending).or(where(status: :processing).where(updated_at: STALLED_PROCESSING_AFTER.ago..))
    }

    def data_json
      @data_json ||= JSON.parse(data)
    rescue JSON::ParserError
      {}
    end

    def to_schema_hash
      @to_schema_hash ||= begin
        mappings = import.mappings.mapped
        schema_fields = import.schema_fields

        attributes = {}
        schema_fields.each do |field|
          attributes[field[:name]] = attribute_by_schema_field(field[:name], mappings)
        end
        attributes
      end
    end

    def attribute_by_schema_field(schema_field, mappings = nil)
      mappings ||= import.mappings.mapped

      mapping = mappings.find { |m| m.schema_field == schema_field }
      return unless mapping&.mapped?

      data_json[mapping.file_column]
    end

    def process!(mappings: nil, schema_fields: nil)
      start_processing!
      self.item = import.row_processor_class.new(self, mappings: mappings, schema_fields: schema_fields).process!
      self.validation_errors = nil # clear a stale error when a retried row succeeds
      complete!
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { import_row_id: id }, source: 'spree.core')
      self.validation_errors = e.message
      fail!
    end

    # Bulk processing mode for large imports.
    # Uses update_columns to skip callbacks, validations, and event publishing.
    def bulk_process!(mappings:, schema_fields:)
      update_columns(status: 'processing', updated_at: Time.current)
      processor = import.row_processor_class.new(self, mappings: mappings, schema_fields: schema_fields)
      self.item = processor.process!
      update_columns(status: 'completed', item_type: item.class.name, item_id: item.id, validation_errors: nil, updated_at: Time.current)
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { import_row_id: id }, source: 'spree.core')
      update_columns(status: 'failed', validation_errors: e.message, updated_at: Time.current)
    end

    def publish_import_row_completed_event
      publish_event('import_row.completed')
    end

    def publish_import_row_failed_event
      publish_event('import_row.failed')
    end
  end
end
