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
  end
end
