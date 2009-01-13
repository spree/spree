unless Spec::Ruby.version.to_f == 1.9
  require File.dirname(__FILE__) + '/../../spec_helper.rb'
  unless [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
    require 'spec/runner/heckle_runner'

    describe "Heckler" do
      it "should run examples on tests_pass?" do
        sub = Class.new(Spec::Runner::Heckler) do
          def initialize(klass_name, method_name, rspec_options)
            @rspec_options = rspec_options
          end
        end
        opts = mock('options')
        opts.should_receive(:run_examples).and_return(true)
        heckler = sub.new('klass','method',opts)
        heckler.tests_pass?
      end
    end
  end
end
