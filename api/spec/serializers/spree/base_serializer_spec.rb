require 'spec_helper'

describe Spree::BaseSerializer do
  subject { described_class }

  describe '.attribute_keys' do
    it 'should return the column names' do
      allow(Spree::Base).to receive(:column_names) { 'example' }
      expect(subject.attribute_keys).to eql 'example'
    end
  end
end
