require File.dirname(__FILE__) + '/../../spec_helper.rb'
require 'fileutils'

describe "OptionParser" do
  before(:each) do
    @out = StringIO.new
    @err = StringIO.new
    @parser = Spec::Runner::OptionParser.new(@err, @out)
  end

  def parse(args)
    @parser.parse(args)
    @parser.options
  end
  
  it "should accept files to include" do
    options = parse(["--pattern", "foo"])
    options.filename_pattern.should == "foo"
  end

  it "should accept dry run option" do
    options = parse(["--dry-run"])
    options.dry_run.should be_true
  end

  it "should eval and use custom formatter when none of the builtins" do
    options = parse(["--format", "Custom::Formatter"])
    options.formatters[0].class.should be(Custom::Formatter)
  end
  
  it "should support formatters with relative and absolute paths, even on windows" do
    options = parse([
      "--format", "Custom::Formatter:C:\\foo\\bar",
      "--format", "Custom::Formatter:foo/bar",
      "--format", "Custom::Formatter:foo\\bar",
      "--format", "Custom::Formatter:/foo/bar"
    ])
    options.formatters[0].where.should eql("C:\\foo\\bar")
    options.formatters[1].where.should eql("foo/bar")
    options.formatters[2].where.should eql("foo\\bar")
    options.formatters[3].where.should eql("/foo/bar")
  end

  it "should not be verbose by default" do
    options = parse([])
    options.verbose.should be_nil
  end

  it "should not use colour by default" do
    options = parse([])
    options.colour.should == false
  end

  it "should print help to stdout if no args" do
    pending 'A regression since 1.0.8' do
      options = parse([])
      @out.rewind
      @out.read.should match(/Usage: spec \(FILE\|DIRECTORY\|GLOB\)\+ \[options\]/m)
    end
  end

  it "should print help to stdout" do
    options = parse(["--help"])
    @out.rewind
    @out.read.should match(/Usage: spec \(FILE\|DIRECTORY\|GLOB\)\+ \[options\]/m)
  end

  it "should print instructions about how to require missing formatter" do
    lambda do 
      options = parse(["--format", "Custom::MissingFormatter"]) 
      options.formatters
    end.should raise_error(NameError)
    @err.string.should match(/Couldn't find formatter class Custom::MissingFormatter/n)
  end

  it "should print version to stdout" do
    options = parse(["--version"])
    @out.rewind
    @out.read.should match(/RSpec-\d+\.\d+\.\d+.*\(build \d+\) - BDD for Ruby\nhttp:\/\/rspec.rubyforge.org\/\n/n)
  end
  
  it "should require file when require specified" do
    lambda do
      parse(["--require", "whatever"])
    end.should raise_error(LoadError)
  end

  it "should support c option" do
    options = parse(["-c"])
    options.colour.should be_true
  end

  it "should support queens colour option" do
    options = parse(["--colour"])
    options.colour.should be_true
  end

  it "should support us color option" do
    options = parse(["--color"])
    options.colour.should be_true
  end

  it "should support single example with -e option" do
    options = parse(["-e", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should support single example with -s option (will be removed when autotest supports -e)" do
    options = parse(["-s", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should support single example with --example option" do
    options = parse(["--example", "something or other"])
    options.examples.should eql(["something or other"])
  end

  it "should read several example names from file if --example is given an existing file name" do
    options = parse(["--example", File.dirname(__FILE__) + '/examples.txt'])
    options.examples.should eql([
      "Sir, if you were my husband, I would poison your drink.", 
      "Madam, if you were my wife, I would drink it."])
  end
  
  it "should read no examples if given an empty file" do
    options = parse(["--example", File.dirname(__FILE__) + '/empty_file.txt'])
    options.examples.should eql([])
  end

  it "should use html formatter when format is h" do
    options = parse(["--format", "h"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
  end

  it "should use html story formatter when format is h" do
    options = parse(["--format", "h"])
    options.story_formatters[0].class.should equal(Spec::Runner::Formatter::Story::HtmlFormatter)
  end

  it "should use html formatter when format is html" do
    options = parse(["--format", "html"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
  end

  it "should use html story formatter when format is html" do
    options = parse(["--format", "html"])
    options.story_formatters[0].class.should equal(Spec::Runner::Formatter::Story::HtmlFormatter)
  end

  it "should use html formatter with explicit output when format is html:test.html" do
    FileUtils.rm 'test.html' if File.exist?('test.html')
    options = parse(["--format", "html:test.html"])
    options.formatters # creates the file
    File.should be_exist('test.html')
    options.formatters[0].class.should equal(Spec::Runner::Formatter::HtmlFormatter)
    options.formatters[0].close
    FileUtils.rm 'test.html'
  end

  it "should use noisy backtrace tweaker with b option" do
    options = parse(["-b"])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::NoisyBacktraceTweaker)
  end

  it "should use noisy backtrace tweaker with backtrace option" do
    options = parse(["--backtrace"])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::NoisyBacktraceTweaker)
  end

  it "should use quiet backtrace tweaker by default" do
    options = parse([])
    options.backtrace_tweaker.should be_instance_of(Spec::Runner::QuietBacktraceTweaker)
  end

  it "should use progress bar formatter by default" do
    options = parse([])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::ProgressBarFormatter)
  end

  it "should use specdoc formatter when format is s" do
    options = parse(["--format", "s"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::SpecdocFormatter)
  end

  it "should use specdoc formatter when format is specdoc" do
    options = parse(["--format", "specdoc"])
    options.formatters[0].class.should equal(Spec::Runner::Formatter::SpecdocFormatter)
  end

  it "should support diff option when format is not specified" do
    options = parse(["--diff"])
    options.diff_format.should == :unified
  end

  it "should use unified diff format option when format is unified" do
    options = parse(["--diff", "unified"])
    options.diff_format.should == :unified
    options.differ_class.should equal(Spec::Expectations::Differs::Default)
  end

  it "should use context diff format option when format is context" do
    options = parse(["--diff", "context"])
    options.diff_format.should == :context
    options.differ_class.should == Spec::Expectations::Differs::Default
  end

  it "should use custom diff format option when format is a custom format" do
    Spec::Expectations.differ.should_not be_instance_of(Custom::Differ)

    options = parse(["--diff", "Custom::Differ"])
    options.parse_diff "Custom::Differ"
    options.diff_format.should == :custom
    options.differ_class.should == Custom::Differ
    Spec::Expectations.differ.should be_instance_of(Custom::Differ)
  end

  it "should print instructions about how to fix missing differ" do
    lambda { parse(["--diff", "Custom::MissingFormatter"]) }.should raise_error(NameError)
    @err.string.should match(/Couldn't find differ class Custom::MissingFormatter/n)
  end

  describe "when attempting a focussed spec" do
    attr_reader :file, :dir
    before do
      @original_rspec_options = $rspec_options
      @file = "#{File.dirname(__FILE__)}/spec_parser/spec_parser_fixture.rb"
      @dir = File.dirname(file)
    end

    after do
      $rspec_options = @original_rspec_options
    end

    def parse(args)
      options = super
      $rspec_options = options
      options.filename_pattern = "*_fixture.rb"
      options
    end

    it "should support --line to identify spec" do
      options = parse([file, "--line", "13"])
      options.line_number.should == 13
      options.examples.should be_empty
      options.run_examples
      options.examples.should eql(["d"])
    end

    it "should fail with error message if file is dir along with --line" do
      options = parse([dir, "--line", "169"])
      options.line_number.should == 169
      options.run_examples
      @err.string.should match(/You must specify one file, not a directory when using the --line option/n)
    end

    it "should fail with error message if file does not exist along with --line" do
      options = parse(["some file", "--line", "169"])
      proc do
        options.run_examples
      end.should raise_error
    end

    it "should fail with error message if more than one files are specified along with --line" do
      options = parse([file, file, "--line", "169"])
      options.run_examples
      @err.string.should match(/Only one file can be specified when using the --line option/n)
    end

    it "should fail with error message if --example and --line are used simultaneously" do
      options = parse([file, "--example", "some example", "--line", "169"])
      options.run_examples
      @err.string.should match(/You cannot use both --line and --example/n)
    end
  end

  if [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
    it "should barf when --heckle is specified (and platform is windows)" do
      lambda do
        options = parse(["--heckle", "Spec"])
      end.should raise_error(StandardError, "Heckle not supported on Windows")
    end
  else
    it "should heckle when --heckle is specified (and platform is not windows)" do
      options = parse(["--heckle", "Spec"])
      options.heckle_runner.should be_instance_of(Spec::Runner::HeckleRunner)
    end
  end

  it "should read options from file when --options is specified" do
    options = parse(["--options", File.dirname(__FILE__) + "/spec.opts"])
    options.diff_format.should_not be_nil
    options.colour.should be_true
  end

  it "should default the formatter to ProgressBarFormatter when using options file" do
    options = parse(["--options", File.dirname(__FILE__) + "/spec.opts"])
    options.formatters.first.should be_instance_of(::Spec::Runner::Formatter::ProgressBarFormatter)
  end

  it "should read spaced and multi-line options from file when --options is specified" do
    options = parse(["--options", File.dirname(__FILE__) + "/spec_spaced.opts"])
    options.diff_format.should_not be_nil
    options.colour.should be_true
    options.formatters.first.should be_instance_of(::Spec::Runner::Formatter::SpecdocFormatter)
  end
   
  it "should save config to file when --generate-options is specified" do
    FileUtils.rm 'test.spec.opts' if File.exist?('test.spec.opts')
    options = parse(["--colour", "--generate-options", "test.spec.opts", "--diff"])
    IO.read('test.spec.opts').should == "--colour\n--diff\n"
    FileUtils.rm 'test.spec.opts'
  end

  it "should save config to file when -G is specified" do
    FileUtils.rm 'test.spec.opts' if File.exist?('test.spec.opts')
    options = parse(["--colour", "-G", "test.spec.opts", "--diff"])
    IO.read('test.spec.opts').should == "--colour\n--diff\n"
    FileUtils.rm 'test.spec.opts'
  end

  it "when --drb is specified, calls DrbCommandLine all of the other ARGV arguments" do
    options = Spec::Runner::OptionParser.parse([
      "some/spec.rb", "--diff", "--colour"
    ], @err, @out)
    Spec::Runner::DrbCommandLine.should_receive(:run).and_return do |options|
      options.argv.should == ["some/spec.rb", "--diff", "--colour"]
    end
    parse(["some/spec.rb", "--diff", "--drb", "--colour"])
  end
  
  it "should reverse spec order when --reverse is specified" do
    options = parse(["some/spec.rb", "--reverse"])
  end

  it "should set an mtime comparator when --loadby mtime" do
    options = parse(["--loadby", 'mtime'])
    runner = Spec::Runner::ExampleGroupRunner.new(options)
    Spec::Runner::ExampleGroupRunner.should_receive(:new).
      with(options).
      and_return(runner)
    runner.should_receive(:load_files).with(["most_recent_spec.rb", "command_line_spec.rb"])

    Dir.chdir(File.dirname(__FILE__)) do
      options.files << 'command_line_spec.rb'
      options.files << 'most_recent_spec.rb'
      FileUtils.touch "most_recent_spec.rb"
      options.run_examples
      FileUtils.rm "most_recent_spec.rb"
    end
  end

  it "should use the standard runner by default" do
    runner = ::Spec::Runner::ExampleGroupRunner.new(@parser.options)
    ::Spec::Runner::ExampleGroupRunner.should_receive(:new).
      with(@parser.options).
      and_return(runner)
    options = parse([])
    options.run_examples
  end

  it "should use a custom runner when given" do
    runner = Custom::ExampleGroupRunner.new(@parser.options, nil)
    Custom::ExampleGroupRunner.should_receive(:new).
      with(@parser.options, nil).
      and_return(runner)
    options = parse(["--runner", "Custom::ExampleGroupRunner"])
    options.run_examples
  end

  it "should use a custom runner with extra options" do
    runner = Custom::ExampleGroupRunner.new(@parser.options, 'something')
    Custom::ExampleGroupRunner.should_receive(:new).
      with(@parser.options, 'something').
      and_return(runner)
    options = parse(["--runner", "Custom::ExampleGroupRunner:something"])
    options.run_examples
  end
end
