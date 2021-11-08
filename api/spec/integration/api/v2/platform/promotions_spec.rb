require 'swagger_helper'

describe 'Promotions API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Promotion'
  options = {
    include_example: 'promotion_category,promotion_rules,promotion_actions,stores',
    filter_examples: [{ name: 'filter[code_eq]', example: 'BLK-FRI' },
                      { name: 'filter[name_cont]', example: 'New Customer' }],
    custom_update_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/update_promotion_params' },
        { '$ref' => '#/components/schemas/update_promotion_add_rule_params' },
        { '$ref' => '#/components/schemas/update_promotion_update_rule_params' },

        { '$ref' => '#/components/schemas/update_promotion_add_action_params' },
        { '$ref' => '#/components/schemas/update_promotion_change_action_params' },

        { '$ref' => '#/components/schemas/update_promotion_action_calculator_params' },
        { '$ref' => '#/components/schemas/update_promotion_change_calculator_params' }
      ]
    }
  }

  let!(:store) { Spree::Store.default }
  let!(:store_two) { create(:store) }
  let!(:store_three) { create(:store) }

  let(:promotion_category) { create(:promotion_category) }
  let(:promotion_rule) { create(:promotion_rule) }

  let(:id) { create(:promotion_with_item_adjustment, promotion_category: promotion_category, promotion_rules: [promotion_rule]).id }
  let!(:records_list) { create_list(:promotion_with_item_adjustment, 3, promotion_category: promotion_category, promotion_rules: [promotion_rule]) }

  let!(:promotion_attibutes) do
    {
      promotion: {
        name: 'Black Friday 20% Off',
        code: 'BLK-20',
        promotion_category_id: promotion_category.id.to_s,
        match_policy: 'any',
        type: 'Spree::Promotion',
        description: 'First 1000 Customers Save 20%',
        starts_at: Time.current,
        expires_at: Time.current + 4.days,
        usage_limit: 1000,
        path: '/black-fri/today',
        advertise: true,
        store_ids: [store_two.id.to_s, store_three.id.to_s]
      }
    }
  end

  let(:valid_create_param_value) do
    promotion_attibutes.merge(
      promotion_rules_attributes: [
        attributes_for(:promotion_rule, code: 'ESJD',
                                        user_id: '223',
                                        product_group_id: '3',
                                        type: 'Spree::Promotion::Rules::User')
      ],
      promotion_actions_attributes: [
        {
          type: 'Spree::Promotion::Actions::FreeShipping',
          position: 1

        }
      ]
    )
  end

  let(:valid_update_param_value) do
    {
      name: '10% OFF',
      code: 'RAND-10',
      description: 'This is the new updated promo',
      advertise: false
    }
  end

  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
