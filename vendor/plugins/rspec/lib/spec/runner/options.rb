module Spec
  module Runner
    class Options
      FILE_SORTERS = {
        'mtime' => lambda {|file_a, file_b| File.mtime(file_b) <=> File.mtime(file_a)}
      }

      EXAMPLE_FORMATTERS = { # Load these lazily for better speed
               'specdoc' => ['spec/runner/formatter/specdoc_formatter',                'Formatter::SpecdocFormatter'],
                     's' => ['spec/runner/formatter/specdoc_formatter',                'Formatter::SpecdocFormatter'],
                  'html' => ['spec/runner/formatter/html_formatter',                   'Formatter::HtmlFormatter'],
                     'h' => ['spec/runner/formatter/html_formatter',                   'Formatter::HtmlFormatter'],
              'progress' => ['spec/runner/formatter/progress_bar_formatter',           'Formatter::ProgressBarFormatter'],
                     'p' => ['spec/runner/formatter/progress_bar_formatter',           'Formatter::ProgressBarFormatter'],
      'failing_examples' => ['spec/runner/formatter/failing_examples_formatter',       'Formatter::FailingExamplesFormatter'],
                     'e' => ['spec/runner/formatter/failing_examples_formatter',       'Formatter::FailingExamplesFormatter'],
'failing_example_groups' => ['spec/runner/formatter/failing_example_groups_formatter', 'Formatter::FailingExampleGroupsFormatter'],
                     'g' => ['spec/runner/formatter/failing_example_groups_formatter', 'Formatter::FailingExampleGroupsFormatter'],
               'profile' => ['spec/runner/formatter/profile_formatter',                'Formatter::ProfileFormatter'],
                     'o' => ['spec/runner/formatter/profile_formatter',                'Formatter::ProfileFormatter'],
              'textmate' => ['spec/runner/formatter/text_mate_formatter',              'Formatter::TextMateFormatter']
      }

      STORY_FORMATTERS = {
        'plain' => ['spec/runner/formatter/story/plain_text_formatter', 'Formatter::Story::PlainTextFormatter'],
            'p' => ['spec/runner/formatter/story/plain_text_formatter', 'Formatter::Story::PlainTextFormatter'],
         'html' => ['spec/runner/formatter/story/html_formatter',       'Formatter::Story::HtmlFormatter'],
            'h' => ['spec/runner/formatter/story/html_formatter',       'Formatter::Story::HtmlFormatter']
      }

      attr_accessor(
        :filename_pattern,
        :backtrace_tweaker,
        :context_lines,
        :diff_format,
        :dry_run,
        :profile,
        :examples,
        :heckle_runner,
        :line_number,
        :loadby,
        :reporter,
        :reverse,
        :timeout,
        :verbose,
        :user_input_for_runner,
        :error_stream,
        :output_stream,
        # TODO: BT - Figure out a better name
        :argv
      )
      attr_reader :colour, :differ_class, :files, :example_groups

      def initialize(error_stream, output_stream)
        @error_stream = error_stream
        @output_stream = output_stream
        @filename_pattern = "**/*_spec.rb"
        @backtrace_tweaker = QuietBacktraceTweaker.new
        @examples = []
        @colour = false
        @profile = false
        @dry_run = false
        @reporter = Reporter.new(self)
        @context_lines = 3
        @diff_format  = :unified
        @files = []
        @example_groups = []
        @examples_run = false
        @examples_should_be_run = nil
        @user_input_for_runner = nil
      end

      def add_example_group(example_group)
        @example_groups << example_group
      end

      def remove_example_group(example_group)
        @example_groups.delete(example_group)
      end

      def run_examples
        return true unless examples_should_be_run?
        runner = custom_runner || ExampleGroupRunner.new(self)

        runner.load_files(files_to_load)
        if example_groups.empty?
          true
        else
          set_spec_from_line_number if line_number
          success = runner.run
          @examples_run = true
          heckle if heckle_runner
          success
        end
      end

      def examples_run?
        @examples_run
      end

      def examples_should_not_be_run
        @examples_should_be_run = false
      end      

      def colour=(colour)
        @colour = colour
        if @colour && RUBY_PLATFORM =~ /win32/ ;\
          begin ;\
            require 'rubygems' ;\
            require 'Win32/Console/ANSI' ;\
          rescue LoadError ;\
            warn "You must 'gem install win32console' to use colour on Windows" ;\
            @colour = false ;\
          end
        end
      end

      def parse_diff(format)
        case format
        when :context, 'context', 'c'
          @diff_format  = :context
          default_differ
        when :unified, 'unified', 'u', '', nil
          @diff_format  = :unified
          default_differ
        else
          @diff_format  = :custom
          self.differ_class = load_class(format, 'differ', '--diff')
        end
      end

      def parse_example(example)
        if(File.file?(example))
          @examples = File.open(example).read.split("\n")
        else
          @examples = [example]
        end
      end

      def parse_format(format_arg)
        format, where = ClassAndArgumentsParser.parse(format_arg)
        unless where
          raise "When using several --format options only one of them can be without a file" if @out_used
          where = @output_stream
          @out_used = true
        end
        @format_options ||= []
        @format_options << [format, where]
      end
      
      def formatters
        @format_options ||= [['progress', @output_stream]]
        @formatters ||= load_formatters(@format_options, EXAMPLE_FORMATTERS)
      end

      def story_formatters
        @format_options ||= [['plain', @output_stream]]
        @formatters ||= load_formatters(@format_options, STORY_FORMATTERS)
      end
      
      def load_formatters(format_options, formatters)
        format_options.map do |format, where|
          formatter_type = if formatters[format]
            require formatters[format][0]
            eval(formatters[format][1], binding, __FILE__, __LINE__)
          else
            load_class(format, 'formatter', '--format')
          end
          formatter_type.new(self, where)
        end
      end

      def load_heckle_runner(heckle)
        suffix = [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM} ? '_unsupported' : ''
        require "spec/runner/heckle_runner#{suffix}"
        @heckle_runner = HeckleRunner.new(heckle)
      end

      def number_of_examples
        @example_groups.inject(0) do |sum, example_group|
          sum + example_group.number_of_examples
        end
      end

      def files_to_load
        result = []
        sorted_files.each do |file|
          if File.directory?(file)
            filename_pattern.split(",").each do |pattern|
              result += Dir[File.expand_path("#{file}/#{pattern.strip}")]
            end
          elsif File.file?(file)
            result << file
          else
            raise "File or directory not found: #{file}"
          end
        end
        result
      end
      
      protected
      def examples_should_be_run?
        return @examples_should_be_run unless @examples_should_be_run.nil?
        @examples_should_be_run = true
      end
      
      def differ_class=(klass)
        return unless klass
        @differ_class = klass
        Spec::Expectations.differ = self.differ_class.new(self)
      end

      def load_class(name, kind, option)
        if name =~ /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/
          arg = $2 == "" ? nil : $2
          [$1, arg]
        else
          m = "#{name.inspect} is not a valid class name"
          @error_stream.puts m
          raise m
        end
        begin
          eval(name, binding, __FILE__, __LINE__)
        rescue NameError => e
          @error_stream.puts "Couldn't find #{kind} class #{name}"
          @error_stream.puts "Make sure the --require option is specified *before* #{option}"
          if $_spec_spec ; raise e ; else exit(1) ; end
        end
      end
      
      def custom_runner
        return nil unless custom_runner?
        klass_name, arg = ClassAndArgumentsParser.parse(user_input_for_runner)
        runner_type = load_class(klass_name, 'behaviour runner', '--runner')
        return runner_type.new(self, arg)
      end

      def custom_runner?
        return user_input_for_runner ? true : false
      end
      
      def heckle
        returns = self.heckle_runner.heckle_with
        self.heckle_runner = nil
        returns
      end
      
      def sorted_files
        return sorter ? files.sort(&sorter) : files
      end

      def sorter
        FILE_SORTERS[loadby]
      end

      def default_differ
        require 'spec/expectations/differs/default'
        self.differ_class = Spec::Expectations::Differs::Default
      end

      def set_spec_from_line_number
        if examples.empty?
          if files.length == 1
            if File.directory?(files[0])
              error_stream.puts "You must specify one file, not a directory when using the --line option"
              exit(1) if stderr?
            else
              example = SpecParser.new.spec_name_for(files[0], line_number)
              @examples = [example]
            end
          else
            error_stream.puts "Only one file can be specified when using the --line option: #{files.inspect}"
            exit(3) if stderr?
          end
        else
          error_stream.puts "You cannot use both --line and --example"
          exit(4) if stderr?
        end
      end

      def stderr?
        @error_stream == $stderr
      end
    end
  end
end
