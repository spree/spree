module Spree
  class ImportMapping < Spree.base_class
    include Spree::SingleStoreResource

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    has_many :imports, class_name: 'Spree::Import', foreign_key: :import_type, primary_key: :type

    #
    # Callbacks
    #
    normalize :external_column_key, with: lambda(&:parameterize)

    #
    # Validations
    #
    validates :store, :import_type, :external_column_key, :external_column_presentation, presence: true
    validates :external_column_key, uniqueness: { scope: [:store_id, :import_type] }
  end
end
