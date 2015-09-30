module Spree
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope { order("LOWER(#{self.table_name}.name)") }

      validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true }
    end
  end
end
