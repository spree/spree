require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryProfiles::OriginGroupsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:profile) { create(:delivery_profile, store: store) }

  describe 'DELETE #destroy' do
    let!(:group) { create(:delivery_origin_group, delivery_profile: profile, name: 'EU') }
    let!(:sibling) { create(:delivery_origin_group, delivery_profile: profile, name: 'US') }

    # The confirm dialog says the group's zones and methods go with it.
    it 'deletes an occupied group and everything it holds' do
      zone = create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: group)
      method = create(:delivery_method, store: store, delivery_profile: profile, delivery_origin_group: group)

      delete :destroy, params: { delivery_profile_id: profile.prefixed_id, id: group.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryOriginGroup.exists?(group.id)).to be(false)
      expect(Spree::DeliveryZone.exists?(zone.id)).to be(false)
      expect(Spree::DeliveryMethod.exists?(method.id)).to be(false)
    end

    # Delivery has to live somewhere: the profile's last group stays.
    it 'refuses the last group of a profile' do
      # The profile factory seeds a default group of its own — clear every
      # sibling so `group` is genuinely the last one standing.
      profile.delivery_origin_groups.where.not(id: group.id).destroy_all

      delete :destroy, params: { delivery_profile_id: profile.prefixed_id, id: group.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Spree::DeliveryOriginGroup.exists?(group.id)).to be(true)
    end
  end
end
