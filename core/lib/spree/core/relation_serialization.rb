module Spree
  module Core
    module RelationSerialization
      def serializable_hash(options = nil)
        self.map { |a| a.serializable_hash(options) }
      end
    end
  end
end