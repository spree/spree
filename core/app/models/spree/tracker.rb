module Spree
  class Tracker < Spree::Base
    enum kind: %i(google_analytics segment)

    validates :analytics_id, presence: true, uniqueness: { scope: :kind, case_sensitive: false }

    scope :active, -> { where(active: true) }

    def self.current(kind = :google_analytics)
      tracker = send(kind).active.first
      tracker&.analytics_id? ? tracker : nil
    end
  end
end
