require 'swagger_helper'

describe 'Orders API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Order'
  resource_path = 'orders'
  options = {
    include_example: 'line_items,variants,product',
    filter_examples: [{ name: 'filter[state_eq]', example: 'complete' }]
  }

  let(:persisted_order) { create(:order_with_line_items, state: :delivery) }
  let(:id) { persisted_order.number }
  let(:records_list) { create_list(:order, 2) }
  let(:store) { Spree::Store.default }
  let(:product) { create(:product, price: 10.0, stores: [store]) }
  let(:country) { create(:country, states_required: true) }
  let(:state) { create(:state, country: country) }
  let(:address_attributes) { build(:address, country: country, state: state).attributes }
  let(:order_attibutes) { attributes_for(:order) }
  let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let(:valid_create_param_value) do
    order_attibutes.merge(
      currency: 'USD',
      bill_address_attributes: address_attributes,
      ship_address_attributes: address_attributes,
      line_items_attributes: [
        attributes_for(:line_item, variant_id: product.master.id, currency: 'USD', quantity: 2)
      ],
      payments_attributes: [
        {
          payment_method_id: payment_method.id,
          source_attributes: {
            number: '4111111111111111',
            month: 12,
            year: Time.current.year + 1,
            verification_value: '123',
            name: 'Spree Commerce'
          }
        }
      ]
    )
  end
  let(:valid_update_param_value) do
    {
      total: 10.00,
      email: 'new@example.com'
    }
  end
  let(:invalid_param_value) do
    {
      email: 'not_valid_email',
      user_id: nil
    }
  end

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, options

    param_name = resource_name.parameterize(separator: '_').to_sym
    post "Creates #{resource_name.articleize}" do
      tags resource_name.pluralize
      consumes 'application/json'
      security [ bearer_auth: [] ]
      description "Creates #{resource_name.articleize}"
      operationId "create-#{resource_name.parameterize.to_sym}"
      parameter name: param_name, in: :body, schema: { '$ref' => "#/components/schemas/create_#{param_name}_params" }
      json_api_include_parameter(options[:include_example])

      let(param_name) { valid_create_param_value }

      it_behaves_like 'record created'
      # it_behaves_like 'invalid request', param_name
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, options
    include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name
  end

  path "/api/v2/platform/#{resource_path}/{id}/advance" do
    patch "Advances #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Advances #{resource_name.articleize}"
      operationId "advance-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/next" do
    patch "Next #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Moves #{resource_name.articleize} to the next state"
      operationId "next-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/complete" do
    before do
      create(:payment, amount: persisted_order.total, order: persisted_order)
    end

    patch "Completes #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Marks #{resource_name.articleize} as completed"
      operationId "complete-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/empty" do
    patch "Empties #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Removes all line items, promotions, shipment and payments from #{resource_name.articleize}"
      operationId "empty-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/approve" do
    patch "Approves #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Approves #{resource_name.articleize}, when using a token created for a user, it will save this user as the approver"
      operationId "approve-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      response '200', 'Record approved' do
        schema '$ref' => '#/components/schemas/resource'
        run_test!
      end
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/cancel" do
    patch "Cancels #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Cancels #{resource_name.articleize}, when using a token created for a user, it will save this user as the canceler"
      operationId "cancel-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      response '200', 'record canceled' do
        let(:id) { create(:completed_order_with_totals).id }
        run_test!
      end
      response '422', 'cannot be canceled' do
        run_test!
      end
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/use_store_credit" do
    patch "Use Store Credit for #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Creates Store Credit payment for #{resource_name.articleize}"
      operationId "use-store-credit-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :amount, in: :body, schema: { '$ref' => '#/components/schemas/amount_param' }
      json_api_include_parameter(options[:include_example])

      let!(:store_credit_payment_method) { create(:store_credit_payment_method) }

      let(:amount) { { amount: 15.0 } }

      response '200', 'store credit payment created' do
        let!(:store_credit) { create(:store_credit, user: persisted_order.user, store: store, amount: 15.0) }
        run_test!
      end
      response '422', 'user does not have store credit available' do
        run_test!
      end
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/apply_coupon_code" do
    patch "Apply Coupon Code for #{resource_name.articleize}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Creates Store Credit payment for #{resource_name.articleize}"
      operationId "apply-coupon-code-#{resource_name.parameterize.to_sym}"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :coupon_code, in: :body, schema: { '$ref' => '#/components/schemas/coupon_code_param' }
      json_api_include_parameter(options[:include_example])

      let!(:promotion) { create(:promotion, name: 'Free shipping', code: 'freeship', stores: [store]) }
      let(:coupon_code) { { coupon_code: promotion.code } }
      let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }

      response '200', 'coupon code applied' do
        run_test!
      end
      response '422', "coupon code couldn't be applied" do
        let(:coupon_code) { { coupon_code: 'wrong-code' } }
        run_test!
      end
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
