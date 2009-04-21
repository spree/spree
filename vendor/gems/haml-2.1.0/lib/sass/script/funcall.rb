module Sass
  module Script
    class Funcall # :nodoc:
      attr_reader :name, :args

      def initialize(name, args)
        @name = name
        @args = args
      end

      def inspect
        "#{name}(#{args.map {|a| a.inspect}.join(', ')})"
      end

      def perform(environment)
        args = self.args.map {|a| a.perform(environment)}
        unless Haml::Util.has?(:public_instance_method, Functions, name) && name !~ /^__/
          return Script::String.new("#{name}(#{args.map {|a| a.perform(environment)}.join(', ')})")
        end

        return Functions.send(name, *args)
      rescue ArgumentError => e
        raise e unless e.backtrace.first =~ /:in `(#{name}|perform)'$/
        raise Sass::SyntaxError.new("#{e.message} for `#{name}'")
      end
    end
  end
end
