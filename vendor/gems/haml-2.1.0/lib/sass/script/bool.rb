require 'sass/script/literal'

module Sass::Script
  class Bool < Literal # :nodoc:
    def to_s
      @value.to_s
    end

    def to_bool
      @value
    end
  end
end
