module Spree
  class ImportRow < Spree.base_class
    #
    # Associations
    #
    belongs_to :import, class_name: 'Spree::Import'
    belongs_to :item, polymorphic: true

    #
    # Validations
    #
    validates :import, :data, presence: true
    validate :row_number, uniqueness: { scope: :import_id }, numericality: { only_integer: true }, presence: true
  end
end
