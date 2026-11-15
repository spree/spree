/**
 * Dashboard assistant types.
 *
 * Hand-written rather than generated: the assistant ships in an optional gem,
 * so its serializers are not part of the core type generation run.
 */

export interface AssistantStatus {
  /** Whether this admin can chat right now — drives whether the panel renders. */
  available: boolean
  provider: string | null
  provider_name: string | null
  model: string | null
  providers: AssistantProviderOption[]
}

export interface AssistantProviderOption {
  key: string
  name: string
  default_model: string
  integration_type: string | null
  /** Whether this vendor has an active integration on the current store. */
  available: boolean
}

export type AssistantToolCallStatus = 'proposed' | 'approved' | 'rejected' | 'executed' | 'failed'

export interface AssistantToolCall {
  id: string
  name: string
  status: AssistantToolCallStatus | null
  /** One line a merchant can judge the change by, without reading arguments. */
  summary: string | null
  arguments: Record<string, unknown>
  result: Record<string, unknown> | null
  /** Records a completed read found, so a reopened chat shows the same
   *  clickable list the merchant saw live. Null for changes. */
  records: AssistantRecord[] | null
  awaiting_approval: boolean
  created_at: string
  resolved_at: string | null
}

export interface AssistantMessage {
  id: string
  role: 'user' | 'assistant' | 'tool'
  content: string | null
  tool_calls: AssistantToolCall[]
  created_at: string
}

export interface AssistantChat {
  id: string
  title: string | null
  message_count: number
  messages?: AssistantMessage[]
  created_at: string
  updated_at: string
}

/**
 * A record a read tool found, in the shape the panel renders: enough to show a
 * row, plus where it lives in the dashboard so the row can be clicked through.
 */
export interface AssistantRecord {
  id: string
  resource: string
  title: string
  subtitle?: string
  status?: string
  image_url?: string
  /** Store-relative dashboard path, e.g. `/products/prod_86Rf07xd4z`. */
  path?: string
}

/** Events the turn endpoints stream. Additive-only — this is public API. */
export type AssistantEventName =
  | 'tool_call.started'
  | 'tool_call.result'
  | 'tool_call.proposed'
  | 'tool_call.resolved'
  | 'message.completed'
  | 'turn.finished'
  | 'turn.failed'

export interface AssistantEvent {
  event: AssistantEventName
  data: {
    text?: string
    name?: string
    summary?: string
    mutating?: boolean
    message?: string
    awaiting_approval?: boolean
    tool_call?: AssistantToolCall
    resource?: string
    /** Rows returned. */
    count?: number
    /** Records that matched, which can exceed the rows returned. */
    total?: number
    records?: AssistantRecord[]
    error?: string
  }
}
