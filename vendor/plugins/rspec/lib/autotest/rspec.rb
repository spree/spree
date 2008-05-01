require 'autotest'

Autotest.add_hook :initialize do |at|
  at.clear_mappings
  # watch out: Ruby bug (1.8.6):
  # %r(/) != /\//
  at.add_mapping(%r%^spec/.*\.rb$%) { |filename, _| 
    filename 
  }
  at.add_mapping(%r%^lib/(.*)\.rb$%) { |_, m| 
    ["spec/#{m[1]}_spec.rb"]
  }
  at.add_mapping(%r%^spec/(spec_helper|shared/.*)\.rb$%) { 
    at.files_matching %r%^spec/.*_spec\.rb$%
  }
end

class RspecCommandError < StandardError; end

class Autotest::Rspec < Autotest

  def initialize
    super

    self.failed_results_re = /^\d+\)\n(?:\e\[\d*m)?(?:.*?Error in )?'([^\n]*)'(?: FAILED)?(?:\e\[\d*m)?\n(.*?)\n\n/m
    self.completed_re = /\Z/ # FIX: some sort of summary line at the end?
  end

  def consolidate_failures(failed)
    filters = Hash.new { |h,k| h[k] = [] }
    failed.each do |spec, failed_trace|
      if f = test_files_for(failed).find { |f| failed_trace =~ Regexp.new(f) } then
        filters[f] << spec
        break
      end
    end
    return filters
  end

  def make_test_cmd(files_to_test)
    return "#{ruby} -S #{spec_command} #{add_options_if_present} #{files_to_test.keys.flatten.join(' ')}"
  end
  
  def add_options_if_present
    File.exist?("spec/spec.opts") ? "-O spec/spec.opts " : ""
  end

  # Finds the proper spec command to use.  Precendence is set in the
  # lazily-evaluated method spec_commands.  Alias + Override that in
  # ~/.autotest to provide a different spec command then the default
  # paths provided.
  def spec_command(separator=File::ALT_SEPARATOR)
    unless defined? @spec_command then
      @spec_command = spec_commands.find { |cmd| File.exists? cmd }

      raise RspecCommandError, "No spec command could be found!" unless @spec_command

      @spec_command.gsub! File::SEPARATOR, separator if separator
    end
    @spec_command
  end

  # Autotest will look for spec commands in the following
  # locations, in this order:
  #
  #   * bin/spec
  #   * default spec bin/loader installed in Rubygems
  def spec_commands
    [
      File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'spec')),
      File.join(Config::CONFIG['bindir'], 'spec')
    ]
  end
end
