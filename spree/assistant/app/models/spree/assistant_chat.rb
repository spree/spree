module Spree
  # One assistant conversation, owned by the admin who started it.
  #
  # Chats are store-scoped and private to their owner: tool results can embed
  # customer data, so another admin's conversation is never readable, and the
  # rows fall under the same erasure expectations as the rest of the store.
  #
  # Persistence is deliberately Spree's own rather than the LLM library's
  # `acts_as_chat`: that would require a models-registry table of LLM metadata
  # in Spree's schema, and it hides the history replay that the approval flow
  # depends on. {Spree::Assistant::RunTurn} rebuilds the conversation from these
  # rows explicitly.
  class AssistantChat < Spree.base_class
    has_prefix_id :chat

    include Spree::SingleStoreResource

    belongs_to :admin_user, class_name: Spree.admin_user_class.to_s

    has_many :assistant_messages,
             -> { order(:id) },
             class_name: 'Spree::AssistantMessage',
             foreign_key: :chat_id,
             inverse_of: :chat,
             dependent: :destroy

    validates :admin_user, presence: true

    scope :owned_by, ->(admin_user) { where(admin_user_id: admin_user.id) }
    scope :recent_first, -> { order(updated_at: :desc) }

    # First thing the merchant said, used as the history label until something
    # better exists. Kept short — this is a sidebar row, not a summary.
    #
    # @param text [String]
    # @return [void]
    def title_from!(text)
      return if title.present? || text.blank?

      # `update!` because the guard above means a silent failure is never
      # retried — the chat would stay untitled for good.
      update!(title: text.to_s.strip.truncate(60))
    end

    # The tool call currently blocking this conversation, if any. A turn halts
    # on the first mutation, but a merchant who ignores a card and simply keeps
    # typing can leave more than one outstanding, so the newest wins.
    #
    # @return [Spree::AssistantToolCall, nil]
    def pending_tool_call
      Spree::AssistantToolCall
        .joins(:message)
        .where(spree_assistant_messages: { chat_id: id })
        .where(status: Spree::AssistantToolCall::PROPOSED)
        # ordered so a chat holding more than one outstanding proposal always
        # resolves the newest, rather than whatever the database returns first
        .order(id: :desc)
        .first
    end
  end
end
