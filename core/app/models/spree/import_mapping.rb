module Spree
  class ImportMapping < Spree.base_class
    #
    # Associations
    #
    belongs_to :import, class_name: 'Spree::Import', inverse_of: :mappings, required: true

    #
    # Validations
    #
    validates :import, :schema_field, presence: true
    validates :schema_field, uniqueness: { scope: [:import_id] }
    validates :file_column, uniqueness: { scope: [:import_id] }, allow_blank: true

    #
    # Scopes
    #
    scope :required, -> { where(schema_field: import.required_fields) }
    scope :mapped, -> { where.not(file_column: [nil, '']) }

    # Returns true if the mapping is required
    # @return [Boolean]
    def required?
      import.required_fields.include?(schema_field)
    end

    # Returns true if the mapping has a file column
    # @return [Boolean]
    def mapped?
      file_column.present?
    end

    def try_to_auto_assign_file_column(csv_headers)
      self.file_column = csv_headers.find { |header| header.parameterize.underscore.downcase.strip == schema_field.parameterize.underscore.downcase.strip }
    end

    # Returns the label for the schema field
    # @return [String]
    def schema_field_label
      @schema_field_label ||= begin
        field = import.schema_fields.find { |field| field[:name] == schema_field }
        field[:label] if field.present?
      end
    end
  end
end
