module Spree
  module Api
    module V3
      module Admin
        # Admin API Consent Record Serializer
        # The evidence trail behind a customer's consent state.
        class ConsentRecordSerializer < BaseSerializer
          typelize purpose: :string, source: :string, accepted: :boolean,
                   email: [:string, nullable: true],
                   ip_address: [:string, nullable: true],
                   recorded_at: [:string, nullable: true],
                   documents: 'Array<Record<string, unknown>>'

          attributes :purpose, :source, :accepted, :email, :ip_address,
                     created_at: :iso8601

          attribute :recorded_at do |record|
            record.recorded_at&.iso8601
          end

          attribute :documents do |record|
            record.documents_list
          end
        end
      end
    end
  end
end
