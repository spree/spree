require "csv"

module Spree
  module Core
    module Converters
      class CSV
        def self.to_csv(rows)
          ::CSV.generate do |csv|
            rows.each do |row|
              csv << row
            end
          end
        end
      end
    end
  end
end
