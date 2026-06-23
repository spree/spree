require 'spec_helper'

describe Spree::Admin::DropdownHelper, type: :helper do
  describe '#flip_placement_for_rtl' do
    context 'when the locale is LTR' do
      before { allow(helper).to receive(:rtl_locale?).and_return(false) }

      it 'returns the placement unchanged' do
        expect(helper.flip_placement_for_rtl('bottom-start')).to eq('bottom-start')
      end
    end

    context 'when the locale is RTL' do
      before { allow(helper).to receive(:rtl_locale?).and_return(true) }

      it 'mirrors start/end placements' do
        expect(helper.flip_placement_for_rtl('bottom-start')).to eq('bottom-end')
        expect(helper.flip_placement_for_rtl('bottom-end')).to eq('bottom-start')
        expect(helper.flip_placement_for_rtl('top-start')).to eq('top-end')
        expect(helper.flip_placement_for_rtl('top-end')).to eq('top-start')
      end

      it 'leaves centered placements unchanged' do
        expect(helper.flip_placement_for_rtl('bottom')).to eq('bottom')
      end
    end
  end
end
