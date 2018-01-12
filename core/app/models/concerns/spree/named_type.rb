module Spree
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope { order(Arel.sql("LOWER(#{table_name}.name)")) }

      validates :name, presence: true, uniqueness: { case_sensitive: false }
    end
  end
end
