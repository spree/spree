require 'spec_helper'

describe 'Load samples' do
  xit 'doesnt raise any error' do
    expect do
      Spree::Seeds::All.call
      SpreeSample::Engine.load_samples
    end.not_to raise_error
  end
end
