module Spree
  module Api
    module V3
      module Admin
        module Assistant
          # Shared base for the assistant endpoints.
          #
          # The assistant is a human surface, so it is JWT-only: a scope-limited
          # secret key has no business opening a conversation that can propose
          # changes to the store. Machine integrations use the Admin API
          # directly.
          class BaseController < Spree::Api::V3::Admin::BaseController
            # Reading a conversation needs `read_assistant`; sending a message
            # or deciding on a proposed change needs `write_assistant` — the
            # default action mapping already draws that line. What the tools
            # inside a conversation may touch is a separate question, answered
            # per tool by its own permission.
            scoped_resource :assistant

            before_action :reject_scope_limited_principal!

            protected

            def reject_scope_limited_principal!
              return unless current_api_key.present? && current_user.blank?

              render json: {
                error: I18n.t('spree.assistant.errors.jwt_only'),
                code: 'assistant_requires_user'
              }, status: :forbidden
            end

            # Who is asking, and where — every tool runs inside this.
            #
            # @return [Spree::Assistant::Context]
            def assistant_context
              @assistant_context ||= Spree::Assistant::Context.new(
                store: current_store,
                user: current_user,
                ability: current_ability
              )
            end

            # Chats are private to their owner: tool results can carry customer
            # data, so another admin's conversation is not readable even with
            # the same permissions. Scoped by store here rather than through a
            # Store association, so core keeps no reference to this optional gem.
            #
            # @return [ActiveRecord::Relation]
            def chats_scope
              Spree::AssistantChat.for_store(current_store).owned_by(current_user)
            end
          end
        end
      end
    end
  end
end
