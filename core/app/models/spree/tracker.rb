module Spree
  class Tracker < Spree::Base
    enum kind: %i(google_analytics segment)

    validates :analytics_id, presence: true, uniqueness: { scope: :kind, case_sensitive: false }

    scope :active, -> { where(active: true) }

    def self.current
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        Spree::Tracker#current is deprecated because you can have multiple
        analytical tracker systems like Google Analytics and Segment
      EOS
      google_analytics.active.first
    end
  end
end
