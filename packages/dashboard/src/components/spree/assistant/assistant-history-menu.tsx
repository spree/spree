import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { ChevronDownIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useAssistantChats, useDeleteAssistantChat } from '../../../hooks/use-assistant'

interface AssistantHistoryMenuProps {
  /** The conversation on screen, so the menu can mark it. */
  currentChatId: string | null
  onSelect: (chatId: string) => void
  onNewChat: () => void
  /** Title of the open conversation, shown as the trigger label. */
  currentTitle?: string | null
}

/**
 * Past conversations, and the way to start a new one.
 *
 * A menu rather than a sidebar: the panel is a narrow column, and history is
 * something a merchant reaches for occasionally rather than reads alongside
 * the answer.
 */
export function AssistantHistoryMenu({
  currentChatId,
  onSelect,
  onNewChat,
  currentTitle,
}: AssistantHistoryMenuProps) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data: chats } = useAssistantChats()
  const deleteChat = useDeleteAssistantChat()

  const label = currentTitle?.trim() || t('admin.assistant.new_chat')

  async function handleDelete(chatId: string, title: string | null) {
    const confirmed = await confirm({
      title: t('admin.assistant.delete_chat'),
      message: t('admin.assistant.delete_chat_confirm', {
        name: title?.trim() || t('admin.assistant.untitled_chat'),
      }),
      confirmLabel: t('admin.assistant.delete_chat'),
      variant: 'destructive',
    })
    if (!confirmed) return

    await deleteChat.mutateAsync(chatId)
    // Deleting the conversation on screen leaves nothing to show, so fall back
    // to a fresh one rather than a transcript whose chat no longer exists.
    if (chatId === currentChatId) onNewChat()
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="-ml-1 h-8 min-w-0 gap-1 px-2 font-medium text-sm">
          <span className="truncate">{label}</span>
          <ChevronDownIcon className="size-3.5 shrink-0 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-72">
        <DropdownMenuItem onClick={onNewChat}>
          <PlusIcon className="size-4" />
          {t('admin.assistant.new_chat')}
        </DropdownMenuItem>

        {chats && chats.length > 0 && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuLabel>{t('admin.assistant.recent_chats')}</DropdownMenuLabel>
            {chats.map((chat) => (
              <DropdownMenuItem
                key={chat.id}
                onClick={() => onSelect(chat.id)}
                className="group/chat justify-between gap-2"
                data-current={chat.id === currentChatId || undefined}
              >
                <span className="min-w-0 truncate data-current:font-medium">
                  {chat.title?.trim() || t('admin.assistant.untitled_chat')}
                </span>
                {/* Kept out of the tab order and hidden until hover: deleting is
                    the rare action here, and a row of bins reads as a warning. */}
                <button
                  type="button"
                  tabIndex={-1}
                  aria-label={t('admin.assistant.delete_chat')}
                  className="shrink-0 rounded p-1 text-muted-foreground opacity-0 transition-opacity hover:bg-accent hover:text-destructive focus-visible:opacity-100 group-hover/chat:opacity-100"
                  onClick={(event) => {
                    // The row navigates; the bin must not.
                    event.stopPropagation()
                    event.preventDefault()
                    void handleDelete(chat.id, chat.title)
                  }}
                >
                  <Trash2Icon className="size-3.5" />
                </button>
              </DropdownMenuItem>
            ))}
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
