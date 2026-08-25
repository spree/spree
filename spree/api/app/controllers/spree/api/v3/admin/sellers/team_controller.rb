module Spree
  module Api
    module V3
      module Admin
        module Sellers
          # The people who run one of the marketplace's sellers.
          #
          # The operator's view of what the seller panel manages for itself. It
          # exists because the operator is the only one who can repair a seller
          # nobody can sign in to any more — the last member left, or the wrong
          # person was invited — which a seller by definition cannot do from
          # inside their own panel.
          #
          # Inviting is not here: it is the `invite` action on the seller
          # itself, which is a lifecycle workflow rather than bookkeeping on a
          # team.
          class TeamController < Admin::BaseController
            scoped_resource :sellers

            before_action :set_seller
            before_action :set_member, only: [:destroy]

            def index
              render json: { data: @seller.users.map { |member| serialize_member(member) } }
            end

            # Revokes a member's access. Unlike the seller's own panel this
            # does not insist on leaving one member behind: emptying the team
            # is a state only the operator can undo, and refusing it here
            # would leave them unable to remove somebody who should not have
            # access — the reason this endpoint exists.
            def destroy
              @seller.remove_user(@member)
              head :no_content
            end

            protected

            def read_actions
              %w[index]
            end

            private

            def set_seller
              @seller = current_store.sellers.find_by_prefix_id!(params[:seller_id])
              authorize! :show, @seller
            end

            def set_member
              @member = @seller.users.find_by_prefix_id!(params[:id])
            end

            def serialize_member(member)
              Spree.api.admin_seller_team_member_serializer.new(
                member, params: { store: current_store }
              ).to_h
            end
          end
        end
      end
    end
  end
end
