module Spree
  class ImportMapping < Spree.base_class
    #
    # Associations
    #
    belongs_to :import

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

    def required?
      import.required_fields.include?(schema_field)
    end

    def mapped?
      file_column.present?
    end

    def try_to_auto_assign_file_column(csv_headers)
      self.file_column = csv_headers.find { |header| header.parameterize.downcase.strip == schema_field.parameterize.downcase.strip }
    end
  end
end
