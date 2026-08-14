module Spree
  module PriceRules
    # Deprecated STI shell, removed in Spree 6.1. Exists only so price-rule
    # rows created before `spree:migrate_tax_zones` runs still load — the task
    # converts each row to a {MarketRule} where the zone's countries match a
    # market exactly, and otherwise deactivates the price list and removes the
    # row, reporting what it named. Never create rows with this class.
    class ZoneRule < Spree::PriceRule
    end
  end
end
