require 'sass/script/literal'

module Sass::Script
  class String < Literal # :nodoc:
    INTERPOLATION = /(^|[^\\])\#\{([^}]*)\}/
    #TODO pass line & char context to perform
    def perform(environment)
      interpolated = @value.gsub(INTERPOLATION) do |match|
        "#{$1}#{Sass::Script.resolve($2, 0, 0, environment)}"
      end
      Sass::Script::String.new(interpolated)
    end

    def plus(other)
      Sass::Script::String.new(self.to_s + other.to_s)
    end

    def minus(other)
      Sass::Script::String.new("#{self.to_s}-#{other.to_s}")
    end

    def unary_minus
      Sass::Script::String.new("-#{self.to_s}")
    end

    def div(other)
      Sass::Script::String.new("#{self.to_s}/#{other.to_s}")
    end

    def unary_div
      Sass::Script::String.new("/#{self.to_s}")
    end

    def funcall(other)
      Sass::Script::String.new("#{self.to_s}(#{other.to_s})")
    end

    def to_s
      @value
    end
  end
end
