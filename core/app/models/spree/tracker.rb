module Spree
  class Tracker < Spree::Base
    TRACKER_ENGINES = %i(google_analytics segment).freeze
    enum engine: TRACKER_ENGINES

    validates :analytics_id, presence: true, uniqueness: { scope: :engine, case_sensitive: false }

    scope :active, -> { where(active: true) }

    def self.current(engine = :google_analytics)
      tracker = send(engine).active.first
      tracker&.analytics_id? ? tracker : nil
    end
  end
end
