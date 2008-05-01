require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    describe 'Nested Example Groups' do
      parent = self
      
      def count
        @count ||= 0
        @count = @count + 1
        @count
      end

      before(:all) do
        count.should == 1
      end

      before(:all) do
        count.should == 2
      end

      before(:each) do
        count.should == 3
      end

      before(:each) do
        count.should == 4
      end

      it "should run before(:all), before(:each), example, after(:each), after(:all) in order" do
        count.should == 5
      end

      after(:each) do
        count.should == 7
      end

      after(:each) do
        count.should == 6
      end

      after(:all) do
        count.should == 9
      end

      after(:all) do
        count.should == 8
      end

      describe 'nested example group' do
        self.superclass.should == parent
        
        it "should run all before and after callbacks" do
          count.should == 5
        end
      end
    end
  end
end
