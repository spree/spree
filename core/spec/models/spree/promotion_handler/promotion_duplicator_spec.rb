require 'spec_helper'

describe Spree::PromotionHandler::PromotionDuplicator do
  subject { described_class.new(promotion) }

  let!(:promo_category) { create(:promotion_category) }
  let!(:calculator) { create(:calculator) }

  let!(:promotion) do
    create(:promotion_with_item_total_rule,
           description: 'Test description',
           expires_at: Date.current + 30,
           starts_at: Date.current,
           usage_limit: 100,
           match_policy: 'all',
           code: 'test1',
           advertise: true,
           path: 'test1',
           promotion_category: promo_category)
  end

  before do
    Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promotion)
  end

  describe '#duplicate' do
    let(:new_promotion) { subject.duplicate }

    context 'model fields' do
      let(:excluded_fields) { ['code', 'name', 'path', 'id', 'created_at', 'updated_at', 'deleted_at'] }

      it 'returns a duplicate of a promotion with the path, name and code fields changed' do
        expect("New #{promotion.name}").to eq new_promotion.name
        expect(new_promotion.path).to match /#{promotion.path}_[a-zA-Z]{4}/
        expect(new_promotion.code).to match /#{promotion.code}_[a-zA-Z]{4}/
      end

      it 'returns a duplicate of a promotion with all the fields (except the path, name and code fields) the same' do
        promotion.attributes.each_key do |key|
          expect(promotion.send(key)).to eq new_promotion.send(key) unless excluded_fields.include?(key)
        end
      end
    end

    context 'model associations - rules' do
      let(:excluded_fields) { ['promotion_id', 'id', 'created_at', 'updated_at', 'deleted_at'] }

      it 'copies all promotion rules' do
        expect(promotion.promotion_rules.size).to eq new_promotion.promotion_rules.size
      end

      it "promotion rule's fields (except promotion_id) are the same" do
        old_rule = promotion.promotion_rules.first
        new_rule = new_promotion.promotion_rules.first

        old_rule.attributes.each_key do |key|
          expect(old_rule.send(key)).to eq new_rule.send(key) unless excluded_fields.include?(key)
        end
      end

      it 'assigns a new promotion rule to new promotion' do
        expect(promotion.promotion_rules.first.promotion_id).not_to eq new_promotion.promotion_rules.first.promotion_id
      end
    end

    context 'model associations - actions' do
      let(:excluded_fields) { ['promotion_id', 'id', 'created_at', 'updated_at', 'deleted_at'] }

      it 'copies all promotion actions' do
        expect(promotion.promotion_actions.size).to eq new_promotion.promotion_actions.size
      end

      it "promotion action's fields (except promotion_id) are the same" do
        old_action = promotion.promotion_actions.first
        new_action = new_promotion.promotion_actions.first

        old_action.attributes.each_key do |key|
          expect(old_action.send(key)).to eq new_action.send(key) unless excluded_fields.include?(key)
        end
      end

      it 'assigns a new promotion action to new promotion' do
        expect(promotion.promotion_actions.first.promotion_id).not_to eq new_promotion.promotion_actions.first.promotion_id
      end
    end

    context "model associations - action's calculator" do
      let(:excluded_fields) { ['calculable_id', 'id', 'created_at', 'updated_at', 'deleted_at'] }

      it "copies promotion action's calculator" do
        new_calc = new_promotion.promotion_actions.first.calculator
        old_calc = promotion.promotion_actions.first.calculator

        new_calc.attributes.each_key do |key|
          expect(old_calc.send(key)).to eq new_calc.send(key) unless excluded_fields.include?(key)
        end
      end

      it 'assigns a new calculator to promotion action' do
        new_calc = new_promotion.promotion_actions.first.calculator
        old_calc = promotion.promotion_actions.first.calculator

        expect(old_calc.calculable_id).not_to eq new_calc.calculable_id
      end
    end
  end
end
