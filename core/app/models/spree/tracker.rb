# DEV NOTE: Remove Spree::Tracker entirely for Spree 3.1.
module Spree
  class Tracker < Spree::Base
    def self.current(options = {})
      options[:deprecation_warning] = true unless options.key? :deprecation_warning
      options[:deprecation_warning] && ActiveSupport::Deprecation.warn(<<-EOS, caller)
\n      The Spree::Tracker model will be removed. To obtain the analytics_id, you can use either
        `current_store.analytics_id' or `Spree::Store.current.analytics_id'.
      EOS
      tracker = where(active: true).first
      tracker.analytics_id.present? ? tracker : nil if tracker
    end
  end
end
