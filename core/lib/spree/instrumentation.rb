module Spree
  class << self
    attr_accessor :instrumenter

    delegate :instrument, :instrument_method, to: :instrumenter
  end

  module Instrumentation
    class Base
      def instrument_method klass, method
        klass.send(:alias_method, :"#{method}_without_instrumentation", method)
        klass.send(:define_method, method) do |*args|
          Spree.instrument("#{klass}.#{method}") do
            send("#{method}_without_instrumentation", *args)
          end
        end
      end
    end
    class Logger < Base
      def instrument name
        Rails.logger.tagged name do
          ret = nil
          ms = Benchmark.ms do
            ret = yield
          end
          Rails.logger.info "Finished in #{ms.round(1)}ms"
          ret
        end
      end
    end
    class None
      def instrument name
        yield
      end
      def instrument_method klass, method
      end
    end
  end

  self.instrumenter = Rails.env.development?? Instrumentation::Logger.new : Instrumentation::None.new
end
