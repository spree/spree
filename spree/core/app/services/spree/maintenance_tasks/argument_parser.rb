module Spree
  module MaintenanceTasks
    # Turns the CLI's `ARGS='market_id=mkt_1 batch_size=200'` into the hash the
    # task's ActiveModel attributes expect.
    #
    # Values stay strings: attribute types cast them, so the parser never has
    # to guess whether `200` is a number or a label.
    module ArgumentParser
      # Quoted values may contain spaces: ARGS='label="two words" limit=5'.
      TOKEN = /(\w+)=("[^"]*"|'[^']*'|\S+)/

      # @param raw [String, nil]
      # @return [Hash{String => String}]
      def self.parse(raw)
        return {} if raw.blank?

        raw.scan(TOKEN).to_h do |key, value|
          [key, value.gsub(/\A["']|["']\z/, '')]
        end
      end
    end
  end
end
