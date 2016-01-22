module Spree
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope -> { order(arel_table[:name].lower) }

      validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true }
    end
  end
end
