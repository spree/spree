require 'spec_helper'

describe 'Load samples' do
  before { Spree::Seeds::All.call }

  it 'doesnt raise any error' do
    skip if Rails::VERSION::MAJOR == 5

    expect do
      SpreeSample::Engine.load_samples
    end.not_to raise_error
  end
end
