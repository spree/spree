module Spree
  class TaxCategory < Spree.base_class
    has_prefix_id :taxcat

    acts_as_paranoid

    include Spree::SingleStoreResource

    validates :name, presence: true,
                     uniqueness: { case_sensitive: false, scope: [:store_id], conditions: -> { where(deleted_at: nil) } }

    has_many :tax_rates, dependent: :destroy, inverse_of: :tax_category
    has_many :products, dependent: :nullify
    has_many :variants, dependent: :nullify

    before_save :set_default_category

    self.whitelisted_ransackable_attributes = %w[name is_default tax_code]

    # The category applied to taxable records that carry none of their own.
    #
    # @param store [Spree::Store, nil] store to look within, the current store by default
    # @return [Spree::TaxCategory, nil]
    def self.default(store = Spree::Current.store)
      scope = store ? for_store(store) : all
      scope.find_by(is_default: true)
    end

    def set_default_category
      # only one category per store is the default, so marking this one demotes
      # the store's previous holder

      if is_default && tax_category = self.class.where(store_id: store_id, is_default: true).where.not(id: id).first
        tax_category.update_columns(is_default: false, updated_at: Time.current)
      end
    end
  end
end
