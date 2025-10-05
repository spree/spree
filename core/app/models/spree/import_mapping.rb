module Spree
  class ImportMapping < Spree.base_class
    #
    # Associations
    #
    belongs_to :mappable, polymorphic: true # Spree::Store, Spree::Vendor, etc.
    has_many :imports, class_name: 'Spree::Import', foreign_key: :import_type, primary_key: :type

    #
    # Callbacks
    #
    normalize :original_column_key, with: ->(value) { value.to_s.parameterize.underscore.strip }

    #
    # Validations
    #
    validates :mappable, :original_column_key, :original_column_presentation, presence: true
    validates :original_column_key, uniqueness: { scope: [:mappable_type, :mappable_id] }
  end
end
