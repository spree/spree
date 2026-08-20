module Spree
  # A tool the model asked to run.
  #
  # Reads never produce one of these — they simply execute. A row exists only
  # for a mutation, which is held here in `proposed` until a human approves or
  # rejects it. That is the assistant's prompt-injection defence: text living in
  # a product description or an order note can ask for a price change, but it
  # cannot get one without a merchant clicking approve.
  class AssistantToolCall < Spree.base_class
    has_prefix_id :tcall

    PROPOSED = 'proposed'.freeze
    APPROVED = 'approved'.freeze
    REJECTED = 'rejected'.freeze
    EXECUTED = 'executed'.freeze
    FAILED = 'failed'.freeze
    STATUSES = [PROPOSED, APPROVED, REJECTED, EXECUTED, FAILED].freeze

    belongs_to :message, class_name: 'Spree::AssistantMessage', inverse_of: :tool_calls

    # The tool-result MESSAGE answering this call — distinct from the `result`
    # column, which holds the outcome data. Named apart deliberately: sharing
    # the name would make `update!(result: {...})` assign a Hash to the
    # association instead of the column.
    has_one :result_message,
            class_name: 'Spree::AssistantMessage',
            foreign_key: :tool_call_id,
            inverse_of: :tool_call,
            dependent: :nullify

    belongs_to :resolved_by,
               class_name: Spree.admin_user_class.to_s,
               optional: true

    validates :tool_call_id, presence: true, uniqueness: true
    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }, allow_nil: true

    scope :pending, -> { where(status: PROPOSED) }

    STATUSES.each do |status_name|
      define_method(:"#{status_name}?") { status == status_name }
    end

    # @return [Boolean] whether a merchant decision is still outstanding
    def awaiting_approval?
      proposed?
    end

    # @return [Hash] arguments with symbol keys, as the tool's #call expects
    def call_arguments
      (arguments || {}).symbolize_keys
    end
  end
end
