module Spree
  module Api
    module TestingSupport
      # rswag helpers for what an admin operation means to agents. Every
      # write action an admin key may call is an agent tool built from its
      # operation; these mark the exceptions in the document itself, where a
      # reviewer sees them next to the endpoint.
      #
      #   patch 'Anonymize a customer' do
      #     agent_tool false, reason: 'Irreversible erasure under GDPR Art. 17.'
      #   end
      #
      #   get 'List quote statuses' do
      #     agent_tool true   # a read becomes a tool only when it opts in
      #   end
      #
      # Core and extensions extend their request specs with this module:
      #
      #   RSpec.configure { |config| config.extend Spree::Api::TestingSupport::AgentTools, type: :request }
      #
      # See docs/plans/6.0-agent-tools-from-openapi.md.
      module AgentTools
        # @param enabled [Boolean]
        # @param reason [String, nil] required to opt a write out
        # @return [void]
        def agent_tool(enabled = true, reason: nil)
          raise ArgumentError, 'an operation opted out of agent tools needs a reason' if !enabled && reason.blank?

          metadata[:operation][Spree::Api::AgentOperations::AGENT_KEY.to_sym] = enabled
          metadata[:operation][Spree::Api::AgentOperations::REASON_KEY.to_sym] = reason if reason
        end
      end
    end
  end
end
