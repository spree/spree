module Spree
  module Assistant
    module TestingSupport
      # Scripts the AI vendor so specs are deterministic and need no API key.
      #
      # The stub sits at the provider's HTTP round trip, which is BELOW payload
      # rendering — so the real messages the model would receive are still
      # built, and {#last_provider_payload} can be asserted on. That matters
      # more than it sounds: the approval flow's one silent failure mode is
      # replaying a stale conversation, and the only way to catch it is to look
      # at what actually went out.
      module ScriptedProvider
        # @param responses [Array<Hash>] provider response bodies, in order
        # @return [void]
        def script_provider(*responses)
          scripted_provider_state[:queue].concat(responses.flatten)
        end

        # The payload the provider was last asked to send.
        #
        # @return [Hash, nil]
        def last_provider_payload
          scripted_provider_state[:payload]
        end

        # Tool results inside the last payload, flattened to text — what the
        # model actually read.
        #
        # @return [String]
        def last_tool_results_text
          messages = last_provider_payload&.dig(:messages) || []

          messages.flat_map { |message| message[:content].is_a?(Array) ? message[:content] : [] }
                  .select { |block| (block[:type] || block['type']).to_s == 'tool_result' }
                  .map { |block| (block[:content] || block['content']).to_s }
                  .join(' ')
        end

        # @return [void]
        def reset_scripted_provider!
          scripted_provider_state[:queue].clear
          scripted_provider_state[:payload] = nil
        end

        # A plain text reply.
        #
        # @return [Hash]
        def provider_text(text)
          {
            'id' => 'msg_text', 'type' => 'message', 'role' => 'assistant', 'model' => 'scripted',
            'content' => [{ 'type' => 'text', 'text' => text }],
            'stop_reason' => 'end_turn', 'usage' => { 'input_tokens' => 1, 'output_tokens' => 1 }
          }
        end

        # A request to run one tool. The tool's own arguments are passed as a
        # hash rather than keywords, so an argument named `id` is never
        # mistaken for the call id.
        #
        # @param name [String, Symbol]
        # @param input [Hash] the tool's arguments
        # @param call_id [String, nil]
        # @return [Hash]
        def provider_tool_use(name, input = {}, call_id: nil)
          {
            'id' => 'msg_tool', 'type' => 'message', 'role' => 'assistant', 'model' => 'scripted',
            'content' => [{ 'type' => 'tool_use', 'id' => call_id || "toolu_#{SecureRandom.hex(4)}",
                            'name' => name.to_s, 'input' => input.deep_stringify_keys }],
            'stop_reason' => 'tool_use', 'usage' => { 'input_tokens' => 5, 'output_tokens' => 5 }
          }
        end

        def scripted_provider_state
          ScriptedProvider.state
        end

        class << self
          def state
            @state ||= { queue: [], payload: nil }
          end

          # Patches the provider once, at load. Idempotent.
          #
          # @return [void]
          def install!
            return if @installed

            ::RubyLLM::Provider.prepend(Interceptor)
            @installed = true
          end
        end

        # Replaces the network call, recording what would have been sent.
        module Interceptor
          def sync_response(_connection, payload, _headers = {})
            state = ScriptedProvider.state
            state[:payload] = payload

            body = state[:queue].shift
            raise "No scripted provider response left for payload: #{payload.inspect}" if body.nil?

            parse_completion_response(Struct.new(:body).new(body))
          end
        end
      end
    end
  end
end

Spree::Assistant::TestingSupport::ScriptedProvider.install!
