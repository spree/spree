module Spec
  module Ruby
    class << self
      def version
        RUBY_VERSION
      end
    end
  end
end
