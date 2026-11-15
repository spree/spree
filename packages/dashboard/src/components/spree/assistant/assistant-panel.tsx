import {
  Badge,
  Bubble,
  BubbleContent,
  Button,
  cn,
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupTextarea,
  Message,
  MessageContent,
  MessageScroller,
  MessageScrollerButton,
  MessageScrollerContent,
  MessageScrollerItem,
  MessageScrollerProvider,
  MessageScrollerViewport,
  Trace,
  TraceCollapsible,
  TraceCollapsibleContent,
  TraceCollapsibleTrigger,
  TraceIcon,
  TraceLine,
  TraceTitle,
} from '@spree/dashboard-ui'
import {
  AlertTriangleIcon,
  ArrowUpIcon,
  CheckIcon,
  Loader2Icon,
  Maximize2Icon,
  Minimize2Icon,
  WrenchIcon,
  XIcon,
} from '@spree/dashboard-ui/icons'
import { type FormEvent, useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import {
  type AssistantTranscriptEntry,
  useAssistantConversation,
} from '../../../hooks/use-assistant'
import { AssistantHistoryMenu } from './assistant-history-menu'
import { AssistantMarkdown } from './assistant-markdown'
import { useAssistant } from './assistant-provider'
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
  const { chatId, chatTitle, entries, streaming, error, send, resolve, load, reset } =
    useAssistantConversation()
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const empty = entries.length === 0
  const { pendingQuestion, clearPendingQuestion } = useAssistant()

  function submit(value: string) {
    const text = value.trim()
    if (!text || streaming) return

    void send(text)
    if (inputRef.current) inputRef.current.value = ''
  }

  // A question asked from the command palette. Cleared as it is sent, so
  // reopening the panel later does not ask it a second time.
  useEffect(() => {
    if (!pendingQuestion || streaming) return
    clearPendingQuestion()
    void send(pendingQuestion)
  }, [pendingQuestion, streaming, send, clearPendingQuestion])

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    submit(inputRef.current?.value ?? '')
  }

  return (
    <div
      // No `aria-label` here: the column that wraps this is the labelled
      // landmark, and a label on a plain div attaches to no role anyway.
      // `bg-card`, matching the page sheet: the two columns are one surface
      // treatment, not a page beside a differently-shaded drawer. The rounding
      // is inherited from the column, so overflow is clipped here to keep the
      // header's rule and the composer inside the card's corners.
      className="flex h-full w-full flex-col overflow-hidden bg-card md:rounded-xl"
    >
      {/* `rail-header-height`, not `header-height`: the latter is the measured
          sticky offset for pinned bands and is legitimately `0` on a page with
          no header, which collapsed this row to nothing. This is a fixed
          chrome row, so it takes the constant the rail's own header rows use. */}
      <header className="flex h-rail-header-height shrink-0 items-center justify-between gap-2 border-b border-border px-4">
        <AssistantHistoryMenu
          currentChatId={chatId}
          currentTitle={chatTitle}
          onSelect={(id) => void load(id)}
          onNewChat={reset}
        />
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

      <div
        className={cn(
          // `min-h-0` so this flex child may shrink below its content and the
          // scroller inside it actually scrolls; scrolling itself belongs to
          // the scroller's viewport, never to this wrapper.
          'min-h-0 flex-1 px-4',
          empty && 'overflow-y-auto',
        )}
      >
        {empty ? (
          <div className="flex h-full flex-col justify-center py-4">
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
          // The scroller follows the reply as it streams and offers a
          // jump-to-latest button when the merchant has scrolled up, so the
          // panel no longer yanks them back mid-read.
          <MessageScrollerProvider autoScroll defaultScrollPosition="last-anchor">
            <MessageScroller className="h-full">
              <MessageScrollerViewport>
                <MessageScrollerContent aria-busy={streaming} className="gap-3 py-4">
                  {groupSteps(entries).map((row) => (
                    <MessageScrollerItem
                      key={row[0].id}
                      messageId={row[0].id}
                      // A merchant's question starts a turn, so anchoring there
                      // keeps the question in view while the answer arrives.
                      scrollAnchor={row[0].kind === 'user'}
                    >
                      {row[0].kind === 'activity' ? (
                        <AssistantSteps steps={row} />
                      ) : (
                        <TranscriptRow entry={row[0]} onResolve={resolve} busy={streaming} />
                      )}
                    </MessageScrollerItem>
                  ))}

                  {streaming && (
                    <div className="flex items-center gap-2 text-muted-foreground text-sm">
                      <Loader2Icon className="size-4 animate-spin" />
                      {t('admin.assistant.thinking')}
                    </div>
                  )}

                  {error && <p className="text-destructive text-sm">{error}</p>}
                </MessageScrollerContent>
              </MessageScrollerViewport>
              <MessageScrollerButton />
            </MessageScroller>
          </MessageScrollerProvider>
        )}
      </div>

      <div className="shrink-0 p-3">
        <form onSubmit={handleSubmit}>
          {/* `bg-background`, not the group's own `bg-card`: the panel itself
              is already the card, so a card-on-card composer has no fill to
              distinguish it and reads as a bare outline. The page ground is
              what reads as an inset field here — the same inversion the rail's
              search box uses. */}
          <InputGroup className="rounded-xl bg-background">
            <InputGroupTextarea
              ref={inputRef}
              rows={2}
              placeholder={t('admin.assistant.placeholder')}
              disabled={streaming}
              className="max-h-40 min-h-0 text-sm"
              onKeyDown={(event) => {
                // Enter sends; Shift+Enter is a newline — chat convention.
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault()
                  submit(inputRef.current?.value ?? '')
                }
              }}
            />
            <InputGroupAddon align="block-end" className="justify-end">
              <InputGroupButton
                type="submit"
                variant="default"
                size="icon-xs"
                className="rounded-full"
                disabled={streaming}
                aria-label={t('admin.assistant.send')}
              >
                <ArrowUpIcon />
              </InputGroupButton>
            </InputGroupAddon>
          </InputGroup>
        </form>
        <p className="mt-2 text-center text-muted-foreground text-xs">
          {t('admin.assistant.disclaimer')}
        </p>
      </div>
    </div>
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
      <Message align="end">
        <MessageContent>
          <Bubble variant="muted" align="end">
            <BubbleContent className="whitespace-pre-wrap">{entry.text}</BubbleContent>
          </Bubble>
        </MessageContent>
      </Message>
    )
  }

  if (entry.kind === 'assistant') {
    return (
      <Message>
        <MessageContent>
          {/* Ghost: a reply spans the column unframed, so records and
              approval cards below it line up with its text. */}
          <Bubble variant="ghost">
            <BubbleContent>
              <AssistantMarkdown text={entry.text ?? ''} />
            </BubbleContent>
          </Bubble>
        </MessageContent>
      </Message>
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

/**
 * Rows for the transcript, with each run of consecutive steps as one row, so
 * the lookups behind an answer read as one list rather than loose lines.
 */
function groupSteps(entries: AssistantTranscriptEntry[]): AssistantTranscriptEntry[][] {
  const rows: AssistantTranscriptEntry[][] = []
  for (const entry of entries) {
    const previous = rows.at(-1)
    if (entry.kind === 'activity' && previous?.[0].kind === 'activity') previous.push(entry)
    else rows.push([entry])
  }
  return rows
}

function AssistantSteps({ steps }: { steps: AssistantTranscriptEntry[] }) {
  return (
    <Trace className="gap-1.5">
      {steps.map((step) => {
        const line = (
          // A finished step takes no status: that is the component's "done".
          <TraceLine status={step.status === 'done' ? undefined : step.status} className="text-xs">
            <TraceIcon>
              {step.status === 'error' ? (
                <AlertTriangleIcon className="size-3.5" />
              ) : (
                <WrenchIcon className="size-3.5" />
              )}
            </TraceIcon>
            <TraceTitle>{step.text}</TraceTitle>
          </TraceLine>
        )

        // Only a failure has more to say; the reason stays folded so one bad
        // lookup does not push the answer down the panel.
        if (step.status === 'error' && step.detail) {
          return (
            <TraceCollapsible key={step.id}>
              <TraceCollapsibleTrigger>{line}</TraceCollapsibleTrigger>
              <TraceCollapsibleContent className="text-xs">{step.detail}</TraceCollapsibleContent>
            </TraceCollapsible>
          )
        }

        return <div key={step.id}>{line}</div>
      })}
    </Trace>
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
