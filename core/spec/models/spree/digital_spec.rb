require 'spec_helper'

describe Spree::Digital, type: :model do
  include ActionDispatch::TestProcess::FixtureFile

  let(:file_upload) { fixture_file_upload(file_fixture('icon_256x256.png'), 'image/png') }
  let(:variant) { create(:variant) }

  it 'validates presence of variant' do
    expect(described_class.new(attachment: file_upload)).not_to be_valid
  end

  it 'validates presence of attachment' do
    expect(described_class.new(variant: variant)).not_to be_valid
  end

  it 'validates presence of attachment and variant' do
    expect(described_class.new(variant: variant, attachment: file_upload)).to be_valid
  end
end
