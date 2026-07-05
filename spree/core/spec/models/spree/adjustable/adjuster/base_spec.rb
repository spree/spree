require 'spec_helper'

describe Spree::Adjustable::Adjuster::Base, type: :model do
  let(:line_item) { create(:line_item) }
  let(:subject) { Spree::Adjustable::Adjuster::Base }

  it 'raises missing update method' do
    expect { subject.adjust(line_item, {}) }.to raise_error(NotImplementedError)
  end
end
