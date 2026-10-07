module Spree
  module Emails
    module Samples
      class CompanyInvitation < Base
        def self.required_permissions
          %w[read_customers]
        end

        def variables
          {
            company: data(store.companies.order(created_at: :desc).first || Spree::Company.new(name: 'Acme Corporation', store: store),
                          Spree.api.company_serializer),
            accept_url: placeholder_url('account/company-invitation')
          }
        end
      end
    end
  end
end
