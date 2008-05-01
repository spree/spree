require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "The anything() mock argument constraint matcher" do
  specify { anything.should == Object.new }
  specify { anything.should == Class }
  specify { anything.should == 1 }
  specify { anything.should == "a string" }
  specify { anything.should == :a_symbol }
end

describe "The boolean() mock argument constraint matcher" do
  specify { boolean.should == true }
  specify { boolean.should == false }
  specify { boolean.should_not == Object.new }
  specify { boolean.should_not == Class }
  specify { boolean.should_not == 1 }
  specify { boolean.should_not == "a string" }
  specify { boolean.should_not == :a_symbol }
end

describe "The an_instance_of() mock argument constraint matcher" do
  # NOTE - this is implemented as a predicate_matcher - see example_group_methods.rb
  specify { an_instance_of(String).should == "string"  }
end
