require 'spec_helper'

describe "Load samples" do
  it "doesn't raise any error" do
    expect {
      SpreeSample::Engine.load_samples
    }.to_not raise_error
  end
end
