require 'spec_helper'

describe 'Load samples' do
  it 'doesnt raise any error' do
    expect do
      SpreeSample::Engine.load_samples
    end.not_to raise_error
  end
end
