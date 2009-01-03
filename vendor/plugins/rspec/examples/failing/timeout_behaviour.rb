require File.dirname(__FILE__) + '/spec_helper'

describe "Something really slow" do
  it "should be failed by RSpec when it takes longer than --timeout" do
    sleep(2)
  end
end
