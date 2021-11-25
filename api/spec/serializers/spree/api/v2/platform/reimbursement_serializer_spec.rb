require 'spec_helper'

describe Spree::Api::V2::Platform::ReimbursementSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:reimbursement_credit) { create(:reimbursement_credit, creditable: create(:store_credit)) }
  let(:payment) { create(:payment, state: 'completed') }
  let(:type) { :reimbursement }
  let(:refund) { create(:refund, amount: payment.credit_allowed - 1) } 
  let(:resource) { create(type, refunds: [refund], credits: [reimbursement_credit]) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          number: resource.number,
          reimbursement_status: resource.reimbursement_status,
          total: resource.total,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          display_total: resource.display_total.to_s,
        },
        relationships: {
          order: {
            data: {
              id: resource.order.id.to_s,
              type: :order
            }
          },
          customer_return: {
            data: {
              id: resource.customer_return.id.to_s,
              type: :customer_return
            }
          },
          refunds: {
            data: [{
              id: refund.id.to_s,
              type: :refund
            }]
          },
          reimbursement_credits: {
            data: [{
              id: reimbursement_credit.id.to_s,
              type: :reimbursement_credit
            }]
          },
          return_items: {
            data: [{
              id: resource.return_items.first.id.to_s,
              type: :return_item
            }]
          }
        },
        type: type
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
