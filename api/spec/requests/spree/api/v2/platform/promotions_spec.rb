require 'spec_helper'

describe 'Promotion API v2 spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let!(:store) { Spree::Store.default }
  let!(:second_store) { create(:store) }
  let!(:third_store) { create(:store) }

  let(:promotion_rule) { create(:promotion_rule) }
  let(:existing_promotion) { create(:promotion_with_item_adjustment, promotion_rules: [promotion_rule]) }
  let(:promotion_category) { create(:promotion_category, code: 'o8ehG', name: 'Super Saver Promotions') }
  let(:promotion_category_two) { create(:promotion_category, code: 'XiP83df-u', name: 'Promotions From 2018') }

  let(:new_promotion_attributes) do
    {
      name: 'Cyber Monday Sale',
      code: 'CM-20',
      promotion_category_id: promotion_category.id.to_s,
      match_policy: 'all',
      type: 'Spree::Promotion',
      description: 'Save big this Cyber Monday - First 100 Customers save 20%',
      starts_at: '2021-10-20 13:09:00 UTC',
      expires_at: '2021-10-25 13:09:00 UTC',
      usage_limit: 100,
      path: '/cyber-monday/today',
      advertise: true,
      store_ids: [second_store.id.to_s],
      promotion_rules_attributes: [
        {
          code: 'ESJD',
          type: 'Spree::Promotion::Rules::User'
        }
      ],
      promotion_actions_attributes: [
        {
          type: 'Spree::Promotion::Actions::FreeShipping',
          position: 1
        }
      ]
    }
  end

  let(:update_promotion_attributes) do
    {
      name: 'Black Friday Sale',
      code: 'BF-20',
      promotion_category_id: promotion_category.id.to_s,
      match_policy: 'any',
      type: 'Spree::Promotion',
      description: 'Black Friday Saver - First 100 Customers save 20%',
      starts_at: '2021-10-20 13:09:00 UTC',
      expires_at: '2021-10-25 13:09:00 UTC',
      usage_limit: 100,
      path: '/black-fri/today',
      advertise: true,
      store_ids: [second_store.id.to_s, third_store.id.to_s],
      promotion_rules_attributes: [
        {
          id: existing_promotion.promotion_rules.first.id.to_s,
          code: 'PliDp9328',
          type: 'Spree::Promotion::Rules::User'
        }
      ],
      promotion_actions_attributes: [
        {
          id: existing_promotion.promotion_actions.first.id.to_s,
          type: 'Spree::Promotion::Actions::FreeShipping'
        }
      ]
    }
  end

  describe 'promotions#create' do
    context 'with valid params' do
      before { post '/api/v2/platform/promotions?include=promotion_category,promotion_actions,promotion_rules,stores', params: params, headers: bearer_token }

      let(:params) { { promotion: new_promotion_attributes } }

      it 'creates and returns a promotion' do
        # promotion
        expect(json_response['data']).to have_attribute(:name).with_value(new_promotion_attributes[:name])
        expect(json_response['data']).to have_attribute(:code).with_value(new_promotion_attributes[:code])
        expect(json_response['data']).to have_attribute(:match_policy).with_value(new_promotion_attributes[:match_policy])
        expect(json_response['data']).to have_attribute(:type).with_value(new_promotion_attributes[:type])
        expect(json_response['data']).to have_attribute(:description).with_value(new_promotion_attributes[:description])
        expect(json_response['data']).to have_attribute(:starts_at).with_value('2021-10-20T13:09:00.000Z')
        expect(json_response['data']).to have_attribute(:expires_at).with_value('2021-10-25T13:09:00.000Z')
        expect(json_response['data']).to have_attribute(:usage_limit).with_value(new_promotion_attributes[:usage_limit])
        expect(json_response['data']).to have_attribute(:path).with_value(new_promotion_attributes[:path])
        expect(json_response['data']).to have_attribute(:advertise).with_value(new_promotion_attributes[:advertise])

        # included promotion_category
        expect(json_response['included']).to include(have_type('promotion_category'))
        expect(json_response['included'][0]).to eq(Spree::Api::V2::Platform::PromotionCategorySerializer.new(promotion_category).as_json['data'])

        # included promotion_action
        expect(json_response['included']).to include(have_type('promotion_action'))
        expect(json_response['included'][1]).to have_attribute(:type).with_value('Spree::Promotion::Actions::FreeShipping')

        # included promotion_rule
        expect(json_response['included']).to include(have_type('promotion_rule'))
        expect(json_response['included'][2]).to have_attribute(:type).with_value('Spree::Promotion::Rules::User')
        expect(json_response['included'][2]).to have_attribute(:code).with_value('ESJD')

        expect(json_response['included'].size).to eq 5
      end
    end

    describe 'promotions#update' do
      before { patch "/api/v2/platform/promotions/#{existing_promotion.id}?include=promotion_category,promotion_actions,promotion_rules,stores", params: params, headers: bearer_token }

      let(:params) { { promotion: update_promotion_attributes } }

      it 'updates and returns a promotion' do
        # promotion
        expect(json_response['data']).to have_attribute(:name).with_value(update_promotion_attributes[:name])
        expect(json_response['data']).to have_attribute(:code).with_value(update_promotion_attributes[:code])
        expect(json_response['data']).to have_attribute(:match_policy).with_value(update_promotion_attributes[:match_policy])
        expect(json_response['data']).to have_attribute(:type).with_value(update_promotion_attributes[:type])
        expect(json_response['data']).to have_attribute(:description).with_value(update_promotion_attributes[:description])
        expect(json_response['data']).to have_attribute(:starts_at).with_value('2021-10-20T13:09:00.000Z')
        expect(json_response['data']).to have_attribute(:expires_at).with_value('2021-10-25T13:09:00.000Z')
        expect(json_response['data']).to have_attribute(:usage_limit).with_value(update_promotion_attributes[:usage_limit])
        expect(json_response['data']).to have_attribute(:path).with_value(update_promotion_attributes[:path])
        expect(json_response['data']).to have_attribute(:advertise).with_value(update_promotion_attributes[:advertise])

        # included promotion_category
        expect(json_response['included']).to include(have_type('promotion_category'))
        expect(json_response['included'][0]).to eq(Spree::Api::V2::Platform::PromotionCategorySerializer.new(promotion_category).as_json['data'])
      end

      it 'updates and returns the nested resources' do
        # included promotion_action
        expect(json_response['included']).to include(have_type('promotion_action'))
        expect(json_response['included'][1]).to have_attribute(:type).with_value('Spree::Promotion::Actions::FreeShipping')

        # # included promotion_rule
        expect(json_response['included']).to include(have_type('promotion_rule'))
        expect(json_response['included'][2]).to have_attribute(:type).with_value('Spree::Promotion::Rules::User')
        expect(json_response['included'][2]).to have_attribute(:code).with_value('PliDp9328')
        expect(json_response['included'].size).to eq 6
      end
    end
  end
end
