# DEV NOTE: Remove Spree::Tracker entirely for Spree 3.1.
module Spree
  class Tracker < Spree::Base
    def self.current
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
\n      The Spree::Tracker model will be removed. To obtain the tracker, you can use either
        `current_store.tracker' or `Spree::Store.current.tracker'.
      EOS
      tracker = where(active: true).first
      tracker.analytics_id.present? ? tracker : nil if tracker
    end
  end
end
