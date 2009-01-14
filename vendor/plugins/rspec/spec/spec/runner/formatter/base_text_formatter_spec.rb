require File.dirname(__FILE__) + '/../../../spec_helper'
require 'spec/runner/formatter/base_text_formatter'
require 'fileutils'

module Spec
  module Runner
    module Formatter
      describe BaseTextFormatter do
        
        before :all do
          @sandbox = "spec/sandbox"
        end

        it "should create the directory contained in WHERE if it does not exist" do
          FileUtils.should_receive(:mkdir_p).with(@sandbox)
          File.stub!(:open)
          BaseTextFormatter.new({},"#{@sandbox}/temp.rb")
        end

      end
    end
  end
end
