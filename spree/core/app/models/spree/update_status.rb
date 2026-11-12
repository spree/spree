module Spree
  # What {Spree::UpdateCheck} last learned about newer releases. Never
  # persisted.
  class UpdateStatus
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :current_version, :string
    attribute :enabled, :boolean, default: true
    # Nil until the first check has finished.
    attribute :checked_at, :datetime
    # Newer releases, newest first: hashes with +version+, +url+ and +published_at+.
    attribute :releases, default: -> { [] }

    # @return [Hash, nil]
    def latest_release
      releases.first
    end

    # @return [Boolean]
    def update_available?
      latest_release.present?
    end
  end
end
