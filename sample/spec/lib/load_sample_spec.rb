require 'spec_helper'

describe "Load samples" do
  before do
    # Seeds are only run for rake test_app so to allow this spec to pass without
    # rerunning rake test_app every time we must load them in if not already.
    unless Spree::Zone.find_by_name("North America")
      load Rails.root + 'Rakefile'
      load Rails.root + 'db/seeds.rb'
    end
  end

  it "doesn't raise any error" do
    expect {
      SpreeSample::Engine.load_samples
    }.to_not raise_error
  end
end
