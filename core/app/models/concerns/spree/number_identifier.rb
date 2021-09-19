module Spree
  module NumberIdentifier
    extend ActiveSupport::Concern

    included do
      before_validation :uppercase_number

      validates :number, presence: true, length: { maximum: 32, allow_blank: true },
                         uniqueness: { allow_blank: true, case_sensitive: true, scope: spree_base_uniqueness_scope }
    end

    protected

    def uppercase_number
      number&.to_s&.upcase!
    end
  end
end
