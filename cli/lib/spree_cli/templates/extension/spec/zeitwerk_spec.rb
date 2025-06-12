require 'spec_helper'

describe 'Zeitwerk' do
  it 'eager loads all files' do
    expect do
      Zeitwerk::Loader.eager_load_all
    end.not_to raise_error
  end
end
