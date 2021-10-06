require 'spec_helper'

describe 'Load samples' do
  before { Spree::Seeds::All.call }

  it 'doesnt raise any error' do
    expect do
      SpreeSample::Engine.load_samples
    end.not_to raise_error
  end
end
