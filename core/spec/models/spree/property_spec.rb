require 'spec_helper'

describe Spree::Property, type: :model do
  context 'setting filter param' do
    subject { build(:property, name: 'Brand Name') }

    it { expect { subject.save! }.to change(subject, :filter_param).from(nil).to('brand-name') }
  end
end
