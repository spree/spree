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
    # Callbacks
    #
    normalizes :file_column_key, with: ->(value) { value.to_s.parameterize.underscore.strip }

    #
    # Scopes
    #
    scope :required, -> { where(schema_field: import.required_fields) }
    scope :mapped, -> { where.not(file_column: nil) }

    def required?
      import.required_fields.include?(schema_field)
    end

    def mapped?
      file_column.present?
    end
  end
end
