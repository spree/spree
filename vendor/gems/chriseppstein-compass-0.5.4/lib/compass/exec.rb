require 'optparse'
require 'rubygems'
require 'haml'
require File.join(Compass.lib_directory, 'compass', 'logger')
require File.join(Compass.lib_directory, 'compass', 'errors')
require File.join(Compass.lib_directory, 'compass', 'actions')

module Compass
  module Exec

    def report_error(e, options)
      $stderr.puts "#{e.class} on line #{get_line e} of #{get_file e}: #{e.message}"
      if options[:trace]
        e.backtrace[1..-1].each { |t| $stderr.puts "  #{t}" }
      else
        $stderr.puts "Run with --trace to see the full backtrace"
      end
    end

    def get_file(exception)
      exception.backtrace[0].split(/:/, 2)[0]
    end

    def get_line(exception)
      # SyntaxErrors have weird line reporting
      # when there's trailing whitespace,
      # which there is for Haml documents.
      return exception.message.scan(/:(\d+)/)[0] if exception.is_a?(::Haml::SyntaxError)
      exception.backtrace[0].scan(/:(\d+)/)[0]
    end
    module_function :report_error, :get_file, :get_line

    class Compass
      
      attr_accessor :args, :options, :opts

      def initialize(args)
        self.args = args
        self.options = {}
        parse!
      end

      def run!
        begin
          perform!
        rescue Exception => e
          raise e if e.is_a? SystemExit
          if e.is_a?(::Compass::Error) || e.is_a?(OptionParser::ParseError)
            $stderr.puts e.message
          else
            ::Compass::Exec.report_error(e, @options)
          end
          return 1
        end
        return 0
      end
      
      protected
      
      def perform!
        if options[:command]
          do_command(options[:command])
        else
          puts self.opts
        end
      end
      
      def parse!
        self.opts = OptionParser.new(&method(:set_opts))
        self.opts.parse!(self.args)    
        if self.args.size > 0
          self.options[:project_name] = trim_trailing_separator(self.args.shift)
        end
        self.options[:command] ||= self.options[:project_name] ? :create_project : :update_project
        self.options[:environment] ||= :production
        self.options[:framework] ||= :compass
        self.options[:project_type] ||= :stand_alone
      end

      def trim_trailing_separator(path)
        path[-1..-1] == File::SEPARATOR ? path[0..-2] : path
      end

      def set_opts(opts)
        opts.banner = <<END
Usage: compass [options] [project]

Description:
  When project is given, generates a new project of that name as a subdirectory of
  the current directory.
  
  If you change any source files, you can update your project using --update.

Options:
END
        opts.on('-u', '--update', :NONE, 'Update the current project') do
          self.options[:command] = :update_project
        end

        opts.on('-w', '--watch', :NONE, 'Monitor the current project for changes and update') do
          self.options[:command] = :watch_project
        end

        opts.on('--sass-dir SRC_DIR', "The source directory where you keep your sass stylesheets.") do |sass_dir|
          self.options[:sass_dir] = sass_dir
        end

        opts.on('--css-dir CSS_DIR', "The target directory where you keep your css stylesheets.") do |css_dir|
          self.options[:css_dir] = css_dir
        end

        opts.on('--list-frameworks', "List compass frameworks available to use.") do
          self.options[:command] = :list_frameworks
        end

        opts.on('-c', '--write-configuration', "Write the current configuration to the configuration file.") do
          self.options[:command] = :write_configuration
        end

        opts.on('-f FRAMEWORK', '--framework FRAMEWORK', 'Set up a new project using the specified framework.') do |framework|
          self.options[:framework] = framework
        end

        opts.on('-e ENV', '--environment ENV', [:development, :production], 'Use sensible defaults for your current environment: development, production (default)') do |env|
          self.options[:environment] = env
        end

        opts.on('-s STYLE', '--output-style STYLE', [:nested, :expanded, :compact, :compressed], 'Select a CSS output mode (nested, expanded, compact, compressed)') do |style|
          self.options[:output_style] = style
        end

        opts.on('-r LIBRARY', '--require LIBRARY', "Require LIBRARY before running commands. This is used to access compass plugins.") do |library|
          require library
        end
        
        opts.on('--rails', "Sets the project type to a rails project.") do
          self.options[:project_type] = :rails
        end

        opts.on('-q', '--quiet', :NONE, 'Quiet mode.') do
          self.options[:quiet] = true
        end

        opts.on('--dry-run', :NONE, 'Dry Run. Tells you what it plans to do.') do
          self.options[:dry_run] = true
        end

        opts.on('--trace', :NONE, 'Show a full stacktrace on error') do
          self.options[:trace] = true
        end
        
        opts.on('--force', :NONE, 'Force. Allows some commands to succeed when they would otherwise fail.') do
          self.options[:force] = true
        end

        opts.on('--imports', :NONE, 'Emit an import path suitable for use with the Sass command-line tool.') do
          #XXX cross platform support?
          print ::Compass::Frameworks::ALL.map{|f| "-I #{f.stylesheets_directory}"}.join(' ')
          exit
        end

        opts.on_tail("-?", "-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on_tail("-v", "--version", "Print version") do
          self.options[:command] = :print_version
        end
      end
      
      def do_command(command)
        command_class_name = command.to_s.split(/_/).map{|p| p.capitalize}.join('')
        command_class = eval("::Compass::Commands::#{command_class_name}")
        command_class.new(Dir.getwd, options).perform
      end

    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'commands', "*.rb")).each do |file|
  require file
end
