module ThoughtBot # :nodoc:
  module Shoulda # :nodoc:
    module Private # :nodoc:
      def get_options!(args, *wanted)
        ret  = []
        opts = (args.last.is_a?(Hash) ? args.pop : {})
        wanted.each {|w| ret << opts.delete(w)}
        raise ArgumentError, "Unsuported options given: #{opts.keys.join(', ')}" unless opts.keys.empty?
        return *ret
      end

      def model_class
        self.name.gsub(/Test$/, '').constantize
      end
    end
  end
end
