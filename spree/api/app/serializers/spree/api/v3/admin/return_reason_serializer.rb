# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ReturnReasonSerializer < V3::ReturnReasonSerializer
          typelize can_be_deleted: :boolean

          attributes created_at: :iso8601, updated_at: :iso8601

          # Lets the dashboard hide destructive controls instead of offering a
          # delete that the model will refuse.
          attribute :can_be_deleted do |reason|
            reason.can_be_deleted?
          end
        end
      end
    end
  end
end
