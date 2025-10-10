require 'spec_helper'

RSpec.describe Spree::Seeds::All do
  subject { described_class.call }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end
end
