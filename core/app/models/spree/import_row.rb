module Spree
  class ImportRow < Spree.base_class
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

    #
    # Scopes
    #
    scope :pending_and_failed, -> { where(status: %i[pending failed]) }
    scope :completed, -> { where(status: :completed) }
    scope :failed, -> { where(status: :failed) }
    scope :processed, -> { where(status: %i[completed failed]) }

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

    def process!
      start_processing!
      self.item = import.row_processor_class.new(self).process!
      complete!
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { import_row_id: id }, source: 'spree.core')
      self.validation_errors = e.message
      fail!
    end

    def publish_import_row_completed_event
      publish_event('import_row.completed')
    end

    def publish_import_row_failed_event
      publish_event('import_row.failed')
    end
  end
end
