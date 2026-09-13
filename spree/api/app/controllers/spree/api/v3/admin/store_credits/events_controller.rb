module Spree
  module Api
    module V3
      module Admin
        module StoreCredits
          # A store credit's ledger: how its balance got to where it is.
          # Read-only — events are written by the credit itself as it is
          # allocated, authorized, captured, voided and credited back.
          class EventsController < ResourceController
            scoped_resource :store_credits

            protected

            def model_class
              Spree::StoreCreditEvent
            end

            def serializer_class
              Spree.api.admin_store_credit_event_serializer
            end

            def parent_association
              :store_credit_events
            end

            def collection_includes
              [:originator]
            end

            # A ledger reads newest first unless the caller asks otherwise.
            def apply_collection_sort(collection)
              return super if sort_param.present?

              collection.reverse_chronological
            end

            # The parent credit is resolved through the store's own credits,
            # so a credit belonging to another store 404s rather than leaking
            # its ledger.
            def set_parent
              @parent = Spree::StoreCredit.
                        for_store(current_store).
                        accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:store_credit_id])
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
