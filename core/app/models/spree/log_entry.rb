module Spree
  class LogEntry < Spree::Base
    if defined?(Spree::Security::LogEntries)
      include Spree::Security::LogEntries
    end

    belongs_to :source, polymorphic: true

    # Fix for #1767
    # If a payment fails, we want to make sure we keep the record of it failing
    after_rollback :save_anyway, if: proc { !Rails.env.test? }

    def save_anyway
      Spree::LogEntry.create!(source: source, details: details)
    end

    def parsed_details
      @details ||= YAML.safe_load(details, [ActiveMerchant::Billing::Response])
    end
  end
end
