import { Badge, Button, cn } from '@spree/dashboard-ui'
import {
  ArrowUpIcon,
  CheckIcon,
  Loader2Icon,
  Maximize2Icon,
  Minimize2Icon,
  WrenchIcon,
  XIcon,
} from 'lucide-react'
import { type FormEvent, useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import {
  type AssistantTranscriptEntry,
  useAssistantConversation,
} from '../../../hooks/use-assistant'
import { AssistantRecords } from './assistant-records'

interface AssistantPanelProps {
  onClose: () => void
  expanded: boolean
  onToggleExpanded: () => void
}

/** Starter prompts, so an empty panel suggests what it is good for. */
const SUGGESTIONS = [
  'admin.assistant.suggestions.products',
  'admin.assistant.suggestions.orders',
  'admin.assistant.suggestions.promotions',
] as const

export function AssistantPanel({ onClose, expanded, onToggleExpanded }: AssistantPanelProps) {
  const { t } = useTranslation()
  const { entries, streaming, error, send, resolve, reset } = useAssistantConversation()
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const bottomRef = useRef<HTMLDivElement>(null)
  const empty = entries.length === 0

  // Follows the answer as it streams in. Depends on both the transcript length
  // and the streaming flag: with an empty dependency list the ref is still null
  // on mount (the anchor only renders once there are entries) and the panel
  // would never scroll at all.
  // biome-ignore lint/correctness/useExhaustiveDependencies: the deps drive the re-run, the body reads neither
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [entries.length, streaming])

  function submit(value: string) {
    const text = value.trim()
    if (!text || streaming) return

    void send(text)
    if (inputRef.current) inputRef.current.value = ''
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    submit(inputRef.current?.value ?? '')
  }

  return (
    <aside
      aria-label={t('admin.assistant.title')}
      className="flex h-full w-full flex-col bg-background"
    >
      <header className="flex h-header-height shrink-0 items-center justify-between gap-2 px-4">
        <button
          type="button"
          onClick={reset}
          className="truncate rounded-md px-1 py-0.5 font-medium text-sm hover:bg-accent"
        >
          {t('admin.assistant.new_chat')}
        </button>
        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            aria-label={t(expanded ? 'admin.assistant.collapse' : 'admin.assistant.expand')}
            onClick={onToggleExpanded}
            className="text-muted-foreground"
          >
            {expanded ? <Minimize2Icon className="size-4" /> : <Maximize2Icon className="size-4" />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={t('admin.assistant.close')}
            onClick={onClose}
            className="text-muted-foreground"
          >
            <XIcon className="size-4" />
          </Button>
        </div>
      </header>

      {/* The dotted field reads as "nothing here yet" without a wall of text,
          and recedes the moment a conversation starts. */}
      <div
        className={cn(
          'flex-1 overflow-y-auto px-4',
          empty &&
            '[background-image:radial-gradient(theme(colors.border)_1px,transparent_1px)] [background-position:0_0] [background-size:16px_16px]',
        )}
      >
        {empty ? (
          <div className="flex h-full flex-col justify-end pb-4">
            <h3 className="flex items-center gap-2 font-semibold text-xl">
              {t('admin.assistant.title')}
              <Badge variant="secondary" className="font-normal">
                {t('admin.assistant.beta')}
              </Badge>
            </h3>
            <p className="mt-2 text-muted-foreground text-sm">{t('admin.assistant.description')}</p>

            <div className="mt-4 space-y-2">
              {SUGGESTIONS.map((key) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => submit(t(key))}
                  className="flex w-full items-center justify-between gap-2 rounded-lg border px-3 py-2.5 text-left text-sm transition-colors hover:bg-accent"
                >
                  <span className="min-w-0">{t(key)}</span>
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="space-y-3 py-4">
            {entries.map((entry) => (
              <TranscriptRow key={entry.id} entry={entry} onResolve={resolve} busy={streaming} />
            ))}

            {streaming && (
              <div className="flex items-center gap-2 text-muted-foreground text-sm">
                <Loader2Icon className="size-4 animate-spin" />
                {t('admin.assistant.thinking')}
              </div>
            )}

            {error && <p className="text-destructive text-sm">{error}</p>}
            <div ref={bottomRef} />
          </div>
        )}
      </div>

      <div className="shrink-0 p-3">
        <form
          onSubmit={handleSubmit}
          className="rounded-xl border bg-background p-2 shadow-sm focus-within:ring-1 focus-within:ring-ring"
        >
          <textarea
            ref={inputRef}
            rows={2}
            placeholder={t('admin.assistant.placeholder')}
            disabled={streaming}
            className="w-full resize-none bg-transparent px-1 py-1 text-sm outline-none placeholder:text-muted-foreground disabled:opacity-50"
            onKeyDown={(event) => {
              // Enter sends; Shift+Enter is a newline — chat convention.
              if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault()
                submit(inputRef.current?.value ?? '')
              }
            }}
          />
          <div className="flex justify-end">
            <Button
              type="submit"
              size="icon"
              className="size-7 rounded-full"
              disabled={streaming}
              aria-label={t('admin.assistant.send')}
            >
              <ArrowUpIcon className="size-4" />
            </Button>
          </div>
        </form>
        <p className="mt-2 text-center text-muted-foreground text-xs">
          {t('admin.assistant.disclaimer')}
        </p>
      </div>
    </aside>
  )
}

function TranscriptRow({
  entry,
  onResolve,
  busy,
}: {
  entry: AssistantTranscriptEntry
  onResolve: (toolCallId: string, approve: boolean) => Promise<void>
  busy: boolean
}) {
  const { t } = useTranslation()

  if (entry.kind === 'user') {
    return (
      <div className="ml-auto max-w-[85%] rounded-lg bg-muted px-3 py-2 text-sm">{entry.text}</div>
    )
  }

  if (entry.kind === 'assistant') {
    return <div className="max-w-[85%] whitespace-pre-wrap text-sm">{entry.text}</div>
  }

  if (entry.kind === 'activity') {
    return (
      <div className="flex items-center gap-2 text-muted-foreground text-xs">
        <WrenchIcon className="size-3" />
        {entry.text}
      </div>
    )
  }

  if (entry.kind === 'records') {
    return <AssistantRecords records={entry.records ?? []} total={entry.total} />
  }

  const toolCall = entry.toolCall
  if (!toolCall) return null

  return (
    <div className="rounded-lg border p-3">
      <div className="flex items-start justify-between gap-2">
        {/* The summary is the whole card: it already says what will change in
            words the merchant reads. Printing the raw arguments underneath
            restated the same thing in a form nobody should have to parse. */}
        <p className="min-w-0 font-medium text-sm">{toolCall.summary || toolCall.name}</p>
        <StatusBadge status={toolCall.status} awaiting={toolCall.awaiting_approval} />
      </div>

      {toolCall.awaiting_approval && (
        <div className="mt-3 flex gap-2">
          <Button size="sm" disabled={busy} onClick={() => void onResolve(toolCall.id, true)}>
            <CheckIcon className="size-4" />
            {t('admin.assistant.approve')}
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={busy}
            onClick={() => void onResolve(toolCall.id, false)}
          >
            <XIcon className="size-4" />
            {t('admin.assistant.reject')}
          </Button>
        </div>
      )}
    </div>
  )
}

function StatusBadge({ status, awaiting }: { status: string | null; awaiting: boolean }) {
  const { t } = useTranslation()

  if (awaiting) return <Badge variant="secondary">{t('admin.assistant.status.proposed')}</Badge>
  if (status === 'executed') return <Badge>{t('admin.assistant.status.executed')}</Badge>
  if (status === 'rejected')
    return <Badge variant="outline">{t('admin.assistant.status.rejected')}</Badge>
  if (status === 'failed')
    return <Badge variant="destructive">{t('admin.assistant.status.failed')}</Badge>

  return null
}
