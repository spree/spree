module Spree
  class LogEntry < Spree::Base
    belongs_to :source, polymorphic: true

    # Fix for #1767
    # If a payment fails, we want to make sure we keep the record of it failing
    after_rollback :save_anyway

    def save_anyway
      Spree::LogEntry.create!(source: source, details: details)
    end

    def parsed_details
      @details ||= YAML.load(details)
    end
  end
end
