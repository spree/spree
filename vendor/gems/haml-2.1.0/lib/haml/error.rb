module Haml
  # An exception raised by Haml code.
  class Error < StandardError
    # :stopdoc:

    # By default, an error is taken to refer to the line of the template
    # that was being processed when the exception was raised.
    # However, if line is non-nil, it + 1 is used instead.
    attr_reader :line

    def initialize(message = nil, line = nil)
      super(message)
      @line = line
    end
    # :startdoc:
  end

  # SyntaxError is the type of exception raised when Haml encounters an
  # ill-formatted document.
  # It's not particularly interesting, except in that it includes Haml::Error.
  class SyntaxError < Haml::Error; end
end
