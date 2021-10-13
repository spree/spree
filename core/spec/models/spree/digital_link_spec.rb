require 'spec_helper'

describe Spree::DigitalLink, type: :model do
  let(:store) { Spree::Store.default }
  let(:digital) { create(:digital) }
  let(:variant) { digital.variant }
  let(:line_item) { create(:line_item, variant: variant) }

  it 'validates presence of digital and line_item' do
    expect(described_class.new(digital: digital, line_item: line_item)).to be_valid
  end

  it 'validates presence of line_item' do
    expect(described_class.new(digital: digital)).not_to be_valid
  end

  it 'validates presence of digital' do
    expect(described_class.new(line_item: line_item)).not_to be_valid
  end

  context 'validates access_counter' do
    it 'validates access_counter numericality' do
      expect(described_class.new(digital: digital, line_item: line_item, access_counter: 'string')).not_to be_valid
    end

    it 'validates access_counter 0 or greater' do
      expect(described_class.new(digital: digital, line_item: line_item, access_counter: -3)).not_to be_valid
    end

    it 'validates access_counter 0 is valid' do
      expect(described_class.new(digital: digital, line_item: line_item, access_counter: 0)).to be_valid
    end
  end

  describe '#reset!' do
    let!(:digital_link_count_check) { create(:digital_link, access_counter: 5) }
    let!(:digital_link_created_at_check) { create(:digital_link) }

    it 'resets created at and access_counter' do
      expect { digital_link_created_at_check.reset! }.to change(digital_link_created_at_check, :created_at)
      expect { digital_link_count_check.reset! }.to change(digital_link_count_check, :access_counter)
    end
  end

  describe '#expired?' do
    context 'out of date' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.update(created_at: 3.years.ago)
        digital_link.save!
        digital_link.reload
      end

      it { expect(digital_link.expired?).to be true }
    end

    context 'out of date but the store does not track date of expire' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.line_item.order.store.update(limit_digital_download_days: false)
        digital_link.line_item.order.store.save!
        digital_link.line_item.order.store.reload
      end

      it { expect(digital_link.expired?).to be false }
    end

    context 'still in date' do
      let(:digital_link) { create(:digital_link) }

      it { expect(digital_link.expired?).to be false }
    end
  end

  describe '#access_limit_exceeded?' do
    context 'count exceeded' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.update(access_counter: 1000)
        digital_link.save!
        digital_link.reload
      end

      it { expect(digital_link.access_limit_exceeded?).to be true }
    end

    context 'count exceeded but the store does not limit digital download count' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.line_item.order.store.update(limit_digital_download_count: false)
        digital_link.line_item.order.store.save!
        digital_link.line_item.order.store.reload
      end

      it { expect(digital_link.access_limit_exceeded?).to be false }
    end

    context 'still in count range' do
      let(:digital_link) { create(:digital_link) }

      it { expect(digital_link.access_limit_exceeded?).to be false }
    end
  end

  describe '#authorizable?' do
    context 'count exceeded' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.update(access_counter: 1000)
        digital_link.save!
        digital_link.reload
      end

      it { expect(digital_link.authorizable?).to be false }
    end

    context 'count exceeded but the store does not limit digital download count' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.line_item.order.store.update(limit_digital_download_count: false)
        digital_link.line_item.order.store.save!
        digital_link.line_item.order.store.reload
      end

      it { expect(digital_link.authorizable?).to be true }
    end

    context 'still in count range' do
      let(:digital_link) { create(:digital_link) }

      it { expect(digital_link.authorizable?).to be true }
    end

    context 'out of date' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.update(created_at: 3.years.ago)
        digital_link.save!
        digital_link.reload
      end

      it { expect(digital_link.authorizable?).to be false }
    end

    context 'out of date but the store does not track date of expire' do
      let(:digital_link) { create(:digital_link) }

      before do
        digital_link.line_item.order.store.update(limit_digital_download_days: false)
        digital_link.line_item.order.store.save!
        digital_link.line_item.order.store.reload
      end

      it { expect(digital_link.authorizable?).to be true }
    end

    context 'still in date' do
      let(:digital_link) { create(:digital_link) }

      it { expect(digital_link.authorizable?).to be true }
    end
  end

  describe 'authorize!' do
    let(:digital_link) { create(:digital_link, access_counter: 2) }

    it 'resets the access counter' do
      digital_link.authorize!
      expect(digital_link.access_counter).to eq(3)
      digital_link.reset!
      expect(digital_link.access_counter).to eq(0)
    end
  end
end
