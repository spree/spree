module Spree
  module Callable
    def self.prepended(base)
      base.singleton_class.prepend ClassMethods
    end

    module ClassMethods
      def call(*args)
        new.call(*args).tap do |result|
          return yield(result) if block_given?
        end
      end
    end
  end
end
