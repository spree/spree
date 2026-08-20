import type {
  AssistantChat,
  AssistantEvent,
  AssistantRecord,
  AssistantStatus,
  AssistantToolCall,
} from '@spree/admin-sdk'
import { adminClient, useStore } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback, useRef, useState } from 'react'

/** What the panel renders: the conversation so far, plus anything in flight. */
export interface AssistantTranscriptEntry {
  id: string
  kind: 'user' | 'assistant' | 'activity' | 'records' | 'proposal'
  text?: string
  toolCall?: AssistantToolCall
  records?: AssistantRecord[]
  resource?: string
  /** Total the tool reported, which can exceed the rows it returned. */
  count?: number
}

export function useAssistantStatus() {
  const { storeId } = useStore()

  return useQuery({
    queryKey: ['assistant', 'status', storeId],
    queryFn: async (): Promise<AssistantStatus> => (await adminClient.assistant.status()).data,
    // The panel asks once per session; connecting a provider is a deliberate
    // act elsewhere in the UI, and a refetch storm on every focus is noise.
    staleTime: 5 * 60 * 1000,
    retry: false,
  })
}

export function useAssistantChats() {
  const { storeId } = useStore()

  return useQuery({
    queryKey: ['assistant', 'chats', storeId],
    queryFn: async (): Promise<AssistantChat[]> => (await adminClient.assistant.chats.list()).data,
  })
}

export function useDeleteAssistantChat() {
  const { storeId } = useStore()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => adminClient.assistant.chats.delete(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['assistant', 'chats', storeId] })
    },
  })
}

/**
 * Drives one conversation: sending a message, streaming the turn, and
 * resolving any change the assistant asks to make.
 */
export function useAssistantConversation() {
  const { storeId } = useStore()
  const queryClient = useQueryClient()
  const [chatId, setChatId] = useState<string | null>(null)
  const [entries, setEntries] = useState<AssistantTranscriptEntry[]>([])
  const [streaming, setStreaming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const abortRef = useRef<AbortController | null>(null)
  const counter = useRef(0)

  const append = useCallback((entry: Omit<AssistantTranscriptEntry, 'id'>) => {
    counter.current += 1
    const id = `entry-${counter.current}`
    setEntries((current) => [...current, { ...entry, id }])
  }, [])

  const handleEvent = useCallback(
    (event: AssistantEvent) => {
      switch (event.event) {
        case 'tool_call.started':
          // Only reads reach here; a mutation arrives as a proposal instead.
          if (!event.data.mutating) {
            append({ kind: 'activity', text: event.data.summary || event.data.name })
          }
          break
        case 'tool_call.result':
          if (event.data.records?.length) {
            append({
              kind: 'records',
              records: event.data.records,
              resource: event.data.resource,
              count: event.data.count,
            })
          } else if (event.data.error) {
            append({ kind: 'activity', text: event.data.error })
          }
          break
        case 'tool_call.proposed':
          if (event.data.tool_call) append({ kind: 'proposal', toolCall: event.data.tool_call })
          break
        case 'tool_call.resolved':
          setEntries((current) =>
            current.map((entry) =>
              entry.kind === 'proposal' && entry.toolCall?.id === event.data.tool_call?.id
                ? { ...entry, toolCall: event.data.tool_call }
                : entry,
            ),
          )
          break
        case 'message.completed':
          if (event.data.text) append({ kind: 'assistant', text: event.data.text })
          break
        case 'turn.failed':
          setError(event.data.message ?? 'Something went wrong.')
          break
        default:
          break
      }
    },
    [append],
  )

  /** Creates the chat lazily, so opening the panel does not litter history. */
  const ensureChat = useCallback(async (): Promise<string> => {
    if (chatId) return chatId

    const created = (await adminClient.assistant.chats.create()).data
    setChatId(created.id)
    void queryClient.invalidateQueries({ queryKey: ['assistant', 'chats', storeId] })
    return created.id
  }, [chatId, queryClient, storeId])

  const send = useCallback(
    async (content: string) => {
      setError(null)
      append({ kind: 'user', text: content })
      setStreaming(true)

      try {
        const id = await ensureChat()
        abortRef.current = new AbortController()
        await adminClient.streamAssistantTurn(
          `/assistant/chats/${id}/messages`,
          { content },
          handleEvent,
          abortRef.current.signal,
        )
      } catch (streamError) {
        if ((streamError as Error).name !== 'AbortError') {
          setError((streamError as Error).message)
        }
      } finally {
        setStreaming(false)
      }
    },
    [append, ensureChat, handleEvent],
  )

  const resolve = useCallback(
    async (toolCallId: string, approve: boolean) => {
      if (!chatId) return
      setError(null)
      setStreaming(true)

      try {
        abortRef.current = new AbortController()
        await adminClient.streamAssistantTurn(
          `/assistant/chats/${chatId}/tool_calls/${toolCallId}/${approve ? 'approve' : 'reject'}`,
          undefined,
          handleEvent,
          abortRef.current.signal,
        )
      } catch (streamError) {
        if ((streamError as Error).name !== 'AbortError') {
          setError((streamError as Error).message)
        }
      } finally {
        setStreaming(false)
      }
    },
    [chatId, handleEvent],
  )

  const load = useCallback(async (id: string) => {
    const chat = (await adminClient.assistant.chats.get(id)).data
    setChatId(chat.id)
    counter.current = 0
    setEntries(
      (chat.messages ?? []).flatMap<AssistantTranscriptEntry>((message) => {
        const rows: AssistantTranscriptEntry[] = []
        if (message.content && message.role !== 'tool') {
          rows.push({
            id: `msg-${message.id}`,
            kind: message.role === 'user' ? 'user' : 'assistant',
            text: message.content,
          })
        }
        for (const toolCall of message.tool_calls ?? []) {
          rows.push({ id: `tc-${toolCall.id}`, kind: 'proposal', toolCall })
        }
        return rows
      }),
    )
  }, [])

  const reset = useCallback(() => {
    abortRef.current?.abort()
    setChatId(null)
    setEntries([])
    setError(null)
    counter.current = 0
  }, [])

  return { chatId, entries, streaming, error, send, resolve, load, reset }
}
