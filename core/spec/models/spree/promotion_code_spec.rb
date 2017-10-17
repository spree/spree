require 'spec_helper'

describe Spree::PromotionCode do
  context 'callbacks' do
    subject { promotion_code.save }

    describe '#downcase_value' do
      let!(:promotion) { create(:promotion) }
      let!(:promotion_code) { build(:promotion_code, promotion: promotion, value: 'NewCoDe') }

      it 'downcases the value before saving' do
        subject
        expect(promotion_code.value).to eq('newcode')
      end
    end
  end

  context '#usage_limit_exceeded?' do
    subject { promotion_code.usage_limit_exceeded?(promotable) }

    let(:promotion) { create(:promotion, :with_order_adjustment, per_code_usage_limit: per_code_usage_limit) }
    let(:promotion_code) { create(:promotion_code, promotion: promotion) }
    let(:promotable) { create(:order) }
    let(:second_promotable) { create(:order) }

    context 'there is a usage limit set' do
      let!(:existing_adjustment) do
        Spree::Adjustment.create!(label: 'Adjustment',
                                  amount: 1,
                                  source: promotion.actions.first,
                                  promotion_code: promotion_code,
                                  order: promotable,
                                  adjustable: promotable)
      end

      context 'the usage limit is not exceeded' do
        let(:per_code_usage_limit) { 10 }

        it 'returns false' do
          expect(promotion_code.usage_limit_exceeded?(promotable)).to be_falsey
        end
      end

      context 'the usage limit is exceeded' do
        let(:per_code_usage_limit) { 1 }

        context 'for a different order' do
          it 'returns true' do
            expect(promotion_code.usage_limit_exceeded?(second_promotable)).to be(true)
          end
        end

        context 'for the same order' do
          let!(:existing_adjustment) do
            Spree::Adjustment.create!(adjustable: promotable,
                                      label: 'Adjustment',
                                      amount: 1,
                                      source: promotion.actions.first,
                                      promotion_code: promotion_code,
                                      order: promotable)
          end

          it 'returns false' do
            expect(subject).to be(false)
          end
        end
      end
    end

    context 'there is no usage limit set' do
      let(:per_code_usage_limit) { nil }

      it 'returns false' do
        expect(subject).to be_falsey
      end
    end
  end

  context '#usage_count' do
    let(:promotable) { create(:order) }
    let(:promotion) { create(:promotion, :with_order_adjustment, code: 'abc123') }
    let(:promotion_code) { promotion.codes.first }
    let!(:adjustment1) do
      Spree::Adjustment.create!(adjustable: promotable,
                                label: 'Adjustment',
                                amount: 1,
                                source: promotion.actions.first,
                                promotion_code: promotion_code,
                                order: promotable)
    end
    let!(:adjustment2) do
      Spree::Adjustment.create!(adjustable: promotable,
                                label: 'Adjustment',
                                amount: 1,
                                source: promotion.actions.first,
                                promotion_code: promotion_code,
                                order: promotable)
    end

    it 'counts the eligible adjustments that have used this promotion' do
      adjustment2.update_columns(eligible: false)
      expect(promotion_code.usage_count).to eq 1
    end
  end
end
