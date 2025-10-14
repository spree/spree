module Spree
  class ImportRow < Spree.base_class
    #
    # Associations
    #
    belongs_to :import, class_name: 'Spree::Import'
    belongs_to :item, polymorphic: true, optional: true # eg. Spree::Variant, Spree::Order, etc.

    #
    # Validations
    #
    validates :import, :data, presence: true
    validates :row_number, uniqueness: { scope: :import_id }, numericality: { only_integer: true, greater_than: 0 }, presence: true

    #
    # State machine
    #
    state_machine initial: :pending, attribute: :status do
      event :started_processing do
        transition to: :processing
      end

      event :fail do
        transition to: :failed
      end
      after_transition to: :failed, do: :add_row_to_import_view
      after_transition to: :failed, do: :update_footer_in_import_view

      event :complete do
        transition to: :completed
      end

      after_transition to: :completed, do: :add_row_to_import_view
      after_transition to: :completed, do: :update_footer_in_import_view
    end

    #
    # Scopes
    #
    scope :pending_and_failed, -> { where(status: %i[pending failed]) }
    scope :completed, -> { where(status: :completed) }
    scope :failed, -> { where(status: :failed) }
    scope :processed, -> { where(status: %i[completed failed]) }

    def mark_import_as_completed
      import.complete! if import.rows.completed.count == import.rows.count
    end

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
          attributes[field[:name]] = attribute_by_schema_field(field[:name], mappings, schema_fields)
        end
        attributes
      end
    end

    def attribute_by_schema_field(schema_field, mappings, schema_fields)
      mapping = mappings.find { |m| m.schema_field == schema_field }
      schema_field = schema_fields.find { |f| f[:name] == schema_field }
      data_json[mapping.file_column]
    end

    def process!
      started_processing!
      self.item = import.row_processor_class.new(self).process!
      complete!
    # rescue StandardError => e
      # fail!(e.message)
    end

    def add_row_to_import_view
      return unless defined?(broadcast_append_to)

      broadcast_append_to "import_#{import_id}_rows", target: 'rows', partial: 'spree/admin/imports/row', locals: { row: self }
    end

    def update_footer_in_import_view
      return unless defined?(broadcast_replace_to)

      broadcast_replace_to "import_#{import_id}_footer", target: 'footer', partial: 'spree/admin/imports/footer', locals: { import: import }
    end
  end
end
