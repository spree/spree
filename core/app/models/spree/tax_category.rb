module Spree
  class TaxCategory < Spree::Base
    acts_as_paranoid
    validates :name, presence: true, uniqueness: { scope: :deleted_at, allow_blank: true }

    has_many :tax_rates, dependent: :destroy, inverse_of: :tax_category

    include DefaultCacheable
  end
end
