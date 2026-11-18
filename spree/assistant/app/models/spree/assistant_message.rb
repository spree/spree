module Spree
  # One message in an assistant conversation: what the merchant asked, what the
  # assistant answered, or the result of a tool call.
  class AssistantMessage < Spree.base_class
    has_prefix_id :msg

    USER = 'user'.freeze
    ASSISTANT = 'assistant'.freeze
    TOOL = 'tool'.freeze
    ROLES = [USER, ASSISTANT, TOOL].freeze

    belongs_to :chat, class_name: 'Spree::AssistantChat', inverse_of: :assistant_messages

    # Set on a tool-RESULT message: which call it answers.
    belongs_to :tool_call,
               class_name: 'Spree::AssistantToolCall',
               optional: true,
               inverse_of: :result_message

    # Set on an ASSISTANT message that asked for tools.
    has_many :tool_calls,
             -> { order(:id) },
             class_name: 'Spree::AssistantToolCall',
             foreign_key: :message_id,
             inverse_of: :message,
             dependent: :destroy

    validates :role, presence: true, inclusion: { in: ROLES }

    scope :for_replay, -> { order(:id) }

    ROLES.each do |role_name|
      define_method(:"#{role_name}?") { role == role_name }
    end
  end
end
