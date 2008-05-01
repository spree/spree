require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe DrbCommandLine, "without running local server" do
      unless Config::CONFIG['ruby_install_name'] == 'jruby'
        it "should print error when there is no running local server" do
          err = StringIO.new
          out = StringIO.new
          DrbCommandLine.run(OptionParser.parse(['--version'], err, out))

          err.rewind
          err.read.should =~ /No server is running/
        end
      end    
    end

    class DrbCommandLineSpec < ::Spec::Example::ExampleGroup
      describe DrbCommandLine, "with local server"

      class CommandLineForSpec
        def self.run(argv, stderr, stdout)
          exit Spec::Runner::CommandLine.run(OptionParser.parse(argv, stderr, stdout))
        end
      end
      
      unless Config::CONFIG['ruby_install_name'] == 'jruby'
        before(:all) do
          DRb.start_service("druby://localhost:8989", CommandLineForSpec)
          @@drb_example_file_counter = 0
        end

        before(:each) do
          create_dummy_spec_file
          @@drb_example_file_counter = @@drb_example_file_counter + 1
        end

        after(:each) do
          File.delete(@dummy_spec_filename)
        end

        after(:all) do
          DRb.stop_service
        end

        it "should run against local server" do
          out = run_spec_via_druby(['--version'])
          out.should =~ /RSpec/n
        end

        it "should output green colorized text when running with --colour option" do
          out = run_spec_via_druby(["--colour", @dummy_spec_filename])
          out.should =~ /\e\[32m/n
        end

        it "should output red colorized text when running with -c option" do
          out = run_spec_via_druby(["-c", @dummy_spec_filename])
          out.should =~ /\e\[31m/n
        end

        def create_dummy_spec_file
          @dummy_spec_filename = File.expand_path(File.dirname(__FILE__)) + "/_dummy_spec#{@@drb_example_file_counter}.rb"
          File.open(@dummy_spec_filename, 'w') do |f|
            f.write %{
              describe "DUMMY CONTEXT for 'DrbCommandLine with -c option'" do
                it "should be output with green bar" do
                  true.should be_true
                end

                it "should be output with red bar" do
                  violated("I want to see a red bar!")
                end
              end
            }
          end
        end

        def run_spec_via_druby(argv)
          err, out = StringIO.new, StringIO.new
          out.instance_eval do
            def tty?; true end
          end
          options = ::Spec::Runner::Options.new(err, out)
          options.argv = argv
          Spec::Runner::DrbCommandLine.run(options)
          out.rewind; out.read
        end
      end

    end
  end
end
