require File.dirname(__FILE__) + '/spec_helper'
require 'spec/runner/formatter/progress_bar_formatter'

# Example of a formatter with custom bactrace printing. Run me with:
# ruby bin/spec examples/failing -r examples/passing/custom_formatter.rb -f CustomFormatter
class CustomFormatter < Spec::Runner::Formatter::ProgressBarFormatter
  def backtrace_line(line)
    line.gsub(/([^:]*\.rb):(\d*)/) do
      "<a href=\"file://#{File.expand_path($1)}\">#{$1}:#{$2}</a> "
    end
  end
end
