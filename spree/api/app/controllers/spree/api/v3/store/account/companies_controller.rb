module Spree
  module Api
    module V3
      module Store
        module Account
          # The signed-in buyer's company memberships — each with its node and
          # ancestor path, so an account page can offer "buying for" choices
          # in one request.
          class CompaniesController < ResourceController
            prepend_before_action :require_authentication!

            # GET /api/v3/store/account/companies
            def index
              memberships = current_user.company_memberships.
                            joins(:company).
                            merge(Spree::Company.where(store_id: current_store.id)).
                            includes(company: :parent)

              render json: {
                'data' => memberships.map do |membership|
                  Spree.api.company_membership_serializer.new(membership, params: serializer_params).to_h.merge(
                    'company' => Spree.api.company_serializer.new(membership.company, params: serializer_params).to_h
                  )
                end
              }
            end

            protected

            def model_class
              Spree::CompanyMembership
            end

            def serializer_class
              Spree.api.company_membership_serializer
            end
          end
        end
      end
    end
  end
end
