require 'test/unit/ui/console/testrunner'

# Completely stolen from redgreen gem
#
# Adds colored output to your tests.  Specify <tt>color: true</tt> in 
# your <tt>~/.shoulda.conf</tt> file to enable.
#
# *Bug*: for some reason, this adds another line of output to the end of 
# every rake task, as though there was another (empty) set of tests.  
# A fix would be most welcome.
#
module ThoughtBot::Shoulda::Color 
  COLORS = { :clear => 0, :red => 31, :green => 32, :yellow => 33 } # :nodoc:
  def self.method_missing(color_name, *args)  # :nodoc:
    color(color_name) + args.first + color(:clear) 
  end
  def self.color(color) # :nodoc:
    "\e[#{COLORS[color.to_sym]}m"
  end
end

module Test # :nodoc:
  module Unit # :nodoc:
    class TestResult # :nodoc:
      alias :old_to_s :to_s
      def to_s
        if old_to_s =~ /\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors/
          ThoughtBot::Shoulda::Color.send($1.to_i != 0 || $2.to_i != 0 ? :red : :green, $&)
        end
      end
    end

    class AutoRunner # :nodoc:
      alias :old_initialize :initialize
      def initialize(standalone)
        old_initialize(standalone)
        @runner = proc do |r| 
          Test::Unit::UI::Console::RedGreenTestRunner
        end
      end
    end

    class Failure # :nodoc:
      alias :old_long_display :long_display
      def long_display
        # old_long_display.sub('Failure', ThoughtBot::Shoulda::Color.red('Failure'))
        ThoughtBot::Shoulda::Color.red(old_long_display)
      end
    end

    class Error # :nodoc:
      alias :old_long_display :long_display
      def long_display
        # old_long_display.sub('Error', ThoughtBot::Shoulda::Color.yellow('Error'))
        ThoughtBot::Shoulda::Color.yellow(old_long_display)
      end
    end

    module UI # :nodoc:
      module Console # :nodoc:
        class RedGreenTestRunner < Test::Unit::UI::Console::TestRunner  # :nodoc:
          def output_single(something, level=NORMAL)
            return unless (output?(level))
            something = case something
            when '.' then ThoughtBot::Shoulda::Color.green('.')
            when 'F' then ThoughtBot::Shoulda::Color.red("F")
            when 'E' then ThoughtBot::Shoulda::Color.yellow("E")
            else something
            end
            @io.write(something) 
            @io.flush
          end
        end
      end
    end
  end
end
