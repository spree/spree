module Spec
  module Runner
    class BacktraceTweaker
      def clean_up_double_slashes(line)
        line.gsub!('//','/')
      end
    end

    class NoisyBacktraceTweaker < BacktraceTweaker
      def tweak_backtrace(error)
        return if error.backtrace.nil?
        tweaked = error.backtrace.collect do |line|
          clean_up_double_slashes(line)
          line
        end
        error.set_backtrace(tweaked)
      end
    end

    # Tweaks raised Exceptions to mask noisy (unneeded) parts of the backtrace
    class QuietBacktraceTweaker < BacktraceTweaker
      unless defined?(IGNORE_PATTERNS)
        root_dir = File.expand_path(File.join(__FILE__, '..', '..', '..', '..'))
        spec_files = Dir["#{root_dir}/lib/*"].map do |path| 
          subpath = path[root_dir.length..-1]
          /#{subpath}/
        end
        IGNORE_PATTERNS = spec_files + [
          /\/lib\/ruby\//,
          /bin\/spec:/,
          /bin\/rcov:/,
          /lib\/rspec-rails/,
          /vendor\/rails/,
          # TextMate's Ruby and RSpec plugins
          /Ruby\.tmbundle\/Support\/tmruby.rb:/,
          /RSpec\.tmbundle\/Support\/lib/,
          /temp_textmate\./,
          /mock_frameworks\/rspec/,
          /spec_server/
        ]
      end
      
      def tweak_backtrace(error)
        return if error.backtrace.nil?
        tweaked = error.backtrace.collect do |message|
          clean_up_double_slashes(message)
          kept_lines = message.split("\n").select do |line|
            IGNORE_PATTERNS.each do |ignore|
              break if line =~ ignore
            end
          end
          kept_lines.empty?? nil : kept_lines.join("\n")
        end
        error.set_backtrace(tweaked.select {|line| line})
      end
    end
  end
end
