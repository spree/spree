module Spree
  class ImportMapping < Spree.base_class
    #
    # Associations
    #
    belongs_to :import

    #
    # Callbacks
    #
    normalizes :original_column_key, with: ->(value) { value.to_s.parameterize.underscore.strip }

    #
    # Validations
    #
    validates :import, :original_column_key, :original_column_presentation, presence: true
    validates :original_column_key, uniqueness: { scope: [:import_id] }
  end
end
