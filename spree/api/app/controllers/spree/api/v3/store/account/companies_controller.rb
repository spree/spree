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

              render json: { 'data' => serialize_collection(memberships) }
            end

            protected

            def model_class
              Spree::CompanyMembership
            end

            def serializer_class
              Spree.api.company_membership_serializer
            end

            # A membership is listed here to choose a company to buy for, so
            # each one always comes with its node.
            def serializer_params
              super.merge(expand: expand_list | ['company'])
            end
          end
        end
      end
    end
  end
end
