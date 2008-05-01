require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe ClassAndArgumentsParser, ".parse" do
      
      it "should use a single : to separate class names from arguments" do
        ClassAndArgumentsParser.parse('Foo').should == ['Foo', nil]
        ClassAndArgumentsParser.parse('Foo:arg').should == ['Foo', 'arg']
        ClassAndArgumentsParser.parse('Foo::Bar::Zap:arg').should == ['Foo::Bar::Zap', 'arg']
        ClassAndArgumentsParser.parse('Foo:arg1,arg2').should == ['Foo', 'arg1,arg2']
        ClassAndArgumentsParser.parse('Foo::Bar::Zap:arg1,arg2').should == ['Foo::Bar::Zap', 'arg1,arg2']
        ClassAndArgumentsParser.parse('Foo::Bar::Zap:drb://foo,drb://bar').should == ['Foo::Bar::Zap', 'drb://foo,drb://bar']
      end

      it "should raise an error when passed an empty string" do
        lambda do
          ClassAndArgumentsParser.parse('')
        end.should raise_error("Couldn't parse \"\"")
      end      
    end
  end
end
