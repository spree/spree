module Spree
  class TaxCategory < Spree::Base
    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

    acts_as_paranoid
    validates :name, presence: true, uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope.push(:deleted_at) }

    has_many :tax_rates, dependent: :destroy, inverse_of: :tax_category
    has_many :products, dependent: :nullify
    has_many :variants, dependent: :nullify

    before_save :set_default_category

    self.whitelisted_ransackable_attributes = %w[name is_default tax_code]

    def set_default_category
      # set existing default tax category to false if this one has been marked as default

      if is_default && tax_category = self.class.where(is_default: true).where.not(id: id).first
        tax_category.update_columns(is_default: false, updated_at: Time.current)
      end
    end
  end
end
