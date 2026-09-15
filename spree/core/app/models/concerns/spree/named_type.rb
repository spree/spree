module Spree
  # Shared behaviour for the reason vocabularies — return, claim, refund and
  # order cancellation. They are store-owned, listed alphabetically, and
  # filtered on `active`, so the scoping lives here rather than being
  # repeated per model.
  module NamedType
    extend ActiveSupport::Concern

    included do
      include Spree::SingleStoreResource

      scope :active, -> { where(active: true) }
      default_scope { order(name: :asc) }

      normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

      validates :name, presence: true
      # Per store, not global: two stores can each have their own "Damaged".
      validates_store_uniqueness :name
    end
  end
end
