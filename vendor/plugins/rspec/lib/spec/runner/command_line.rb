require 'spec/runner/option_parser'

module Spec
  module Runner
    class CommandLine
      def self.run(tmp_options=Spec::Runner.options)
        orig_options = Spec::Runner.options
        Spec::Runner.use tmp_options
        tmp_options.run_examples
      ensure
        Spec::Runner.use orig_options
      end
    end
  end
end
