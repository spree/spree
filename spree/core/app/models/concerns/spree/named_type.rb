module Spree
  module NamedType
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
      default_scope { order(name: :asc) }

      include Spree::UniqueName

      # Core seeds a handful of reasons it looks up by name (RefundReason's
      # "Return processing", for instance) and marks them immutable. Renaming
      # or deleting one silently breaks the flow that finds it, so the guard
      # lives on the model rather than only in the ability layer — API keys
      # authorize by scope and never consult CanCanCan.
      validate :name_is_not_locked, on: :update
      before_destroy :abort_if_locked
    end

    # @return [Boolean] false when core depends on this record staying as it is
    def can_be_deleted?
      !locked?
    end

    private

    # Not every NamedType carries the column, so ask the record itself rather
    # than the class — checking column_names at include time would hit the
    # database during boot.
    def locked?
      has_attribute?(:mutable) && !mutable?
    end

    def name_is_not_locked
      return unless locked? && name_changed?

      errors.add(:name, :immutable_named_type)
    end

    def abort_if_locked
      return unless locked?

      errors.add(:base, :immutable_named_type)
      throw(:abort)
    end
  end
end
