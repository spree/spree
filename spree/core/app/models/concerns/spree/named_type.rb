module Spree
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope { order(name: :asc) }

      include Spree::UniqueName
    end
  end
end
