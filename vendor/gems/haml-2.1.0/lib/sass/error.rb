module Sass
  # Sass::SyntaxError encapsulates information about the exception,
  # such as the line of the Sass template it was raised on
  # and the Sass file that was being parsed (if applicable).
  # It also provides a handy way to rescue only exceptions raised
  # because of a faulty template.
  class SyntaxError < StandardError
    # The line of the Sass template on which the exception was thrown.
    attr_accessor :sass_line

    # The name of the file that was being parsed when the exception was raised.
    # This will be nil unless Sass is being used as an ActionView plugin.
    attr_reader :sass_filename

    # Creates a new SyntaxError.
    # +lineno+ should be the line of the Sass template on which the error occurred.
    def initialize(msg, lineno = nil)
      @message = msg
      @sass_line = lineno
    end

    # Adds a properly formatted entry to the exception's backtrace.
    # +filename+ should be the file in which the error occurred,
    # if applicable (defaults to "(sass)").
    def add_backtrace_entry(filename) # :nodoc:
      @sass_filename ||= filename
      self.backtrace ||= []
      self.backtrace.unshift "#{@sass_filename || '(sass)'}:#{@sass_line}"
    end

    def to_s # :nodoc:
      @message
    end
  end
end
