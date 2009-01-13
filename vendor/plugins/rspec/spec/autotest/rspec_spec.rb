require File.dirname(__FILE__) + "/autotest_helper"

class Autotest
  
  describe Rspec do
    describe "adding spec.opts --options" do 
      before(:each) do
        @rspec_autotest = Rspec.new
      end

      it "should return the command line option to add spec.opts if the options file exists" do
        File.stub!(:exist?).and_return true
        @rspec_autotest.add_options_if_present.should == "-O spec/spec.opts "
      end

      it "should return an empty string if no spec.opts exists" do
        File.stub!(:exist?).and_return false
        Rspec.new.add_options_if_present.should == ""
      end
    end  
  
    describe "commands" do
      before(:each) do
        @rspec_autotest = Rspec.new
        @rspec_autotest.stub!(:ruby).and_return "ruby"
        @rspec_autotest.stub!(:add_options_if_present).and_return "-O spec/spec.opts"
      
        @ruby = @rspec_autotest.ruby
        @spec_cmd = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'spec'))
        @options = @rspec_autotest.add_options_if_present
        @files_to_test = {
          :spec => ["file_one", "file_two"]
        }
        # this is not the inner representation of Autotest!
        @rspec_autotest.stub!(:files_to_test).and_return @files_to_test
        @files_to_test.stub!(:keys).and_return @files_to_test[:spec]
        @to_test = @files_to_test.keys.flatten.join ' '
      end
    
      it "should make the appropriate test command" do
        @rspec_autotest.make_test_cmd(@files_to_test).should == "#{@ruby} #{@spec_cmd} #{@to_test} #{@options}"
      end

      it "should return a blank command for no files" do
        @rspec_autotest.make_test_cmd({}).should == ''
      end
    end
  
    describe "mappings" do
    
      before(:each) do
        @lib_file = "lib/something.rb"
        @spec_file = "spec/something_spec.rb"
        @rspec_autotest = Rspec.new
        @rspec_autotest.hook :initialize
      end
    
      it "should find the spec file for a given lib file" do
        @rspec_autotest.should map_specs([@spec_file]).to(@lib_file)
      end
    
      it "should find the spec file if given a spec file" do
        @rspec_autotest.should map_specs([@spec_file]).to(@spec_file)
      end
    
      it "should ignore files in spec dir that aren't specs" do
        @rspec_autotest.should map_specs([]).to("spec/spec_helper.rb")
      end
    
      it "should ignore untracked files (in @file)"  do
        @rspec_autotest.should map_specs([]).to("lib/untracked_file")
      end
    end
  
    describe "consolidating failures" do
      before(:each) do
        @rspec_autotest = Rspec.new
      
        @spec_file = "spec/autotest/some_spec.rb"
        @rspec_autotest.instance_variable_set("@files", {@spec_file => Time.now})
        @rspec_autotest.stub!(:find_files_to_test).and_return true
      end
    
      it "should return no failures if no failures were given in the output" do
        @rspec_autotest.consolidate_failures([[]]).should == {}
      end
    
      it "should return a hash with the spec filename => spec name for each failure or error" do
        @rspec_autotest.stub!(:test_files_for).and_return "spec/autotest/some_spec.rb"
        failures = [
          [
            "false should be false", 
            "expected: true,\n     got: false (using ==)\n#{@spec_file}:203:"
          ]
        ]
        @rspec_autotest.consolidate_failures(failures).should == {
          @spec_file => ["false should be false"]
        }
      end
    
      it "should not include the subject file" do
        subject_file = "lib/autotest/some.rb"
        @rspec_autotest.stub!(:test_files_for).and_return "spec/autotest/some_spec.rb"
        failures = [
          [
            "false should be false", 
            "expected: true,\n     got: false (using ==)\n#{subject_file}:143:\n#{@spec_file}:203:"
          ]
        ]
        @rspec_autotest.consolidate_failures(failures).keys.should_not include(subject_file)
      end
    end
  end
end
