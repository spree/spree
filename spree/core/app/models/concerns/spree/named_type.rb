module Spree
  # Shared behaviour for the reason vocabularies — return, claim, refund and
  # order cancellation.
  #
  # All of them are store-owned, so the scoping lives here rather than being
  # repeated per model. `UniqueName` stays the general concern for globally
  # unique named records (Role, OptionType, Zone); this one narrows it to
  # per-store names.
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope { order(name: :asc) }

      include Spree::SingleStoreResource

      normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

      # Per store, not global: two stores can each have their own "Damaged".
      # Backed by a unique (store_id, name) index on each table.
      validates :name, presence: true,
                       uniqueness: {
                         case_sensitive: false,
                         allow_blank: true,
                         scope: [:store_id, *spree_base_uniqueness_scope]
                       }
    end
  end
end
