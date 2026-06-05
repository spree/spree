import { CheckIcon, CopyIcon } from 'lucide-react'
import type { ComponentProps, ReactNode } from 'react'
import { useCopyToClipboard } from '../hooks/use-copy-to-clipboard'
import { cn } from '../lib/utils'
import { Button } from '../ui/button'

type ButtonProps = ComponentProps<typeof Button>

type CopyToClipboardButtonProps = Omit<ButtonProps, 'onClick' | 'children'> & {
  /** Text to write to the clipboard. */
  value: string
  /** Accessible label for the button — required by a11y rules. */
  'aria-label': string
  /** Custom icon for the idle state. Defaults to `CopyIcon`. */
  icon?: ReactNode
  /** Custom icon for the copied state. Defaults to `CheckIcon`. */
  copiedIcon?: ReactNode
  /** Optional label rendered alongside the icon (e.g. "Copy"). */
  label?: ReactNode
  /** Optional label rendered alongside the icon while in the copied state. */
  copiedLabel?: ReactNode
  /**
   * How long the copied state stays true after a successful copy. Forwarded to
   * `useCopyToClipboard`. Defaults to 1200ms (the hook's default).
   */
  resetMs?: number
  /**
   * Stop the click event from bubbling. Useful inside `<ResourceTable>` rows
   * where `useRowClickBridge` would otherwise also fire. Defaults to `true`
   * since that's the common case — pass `false` to opt out.
   */
  stopPropagation?: boolean
}

/**
 * Universal copy-to-clipboard button. Renders a standard `<Button>` with a
 * copy icon that flips to a check icon for a short flash after a successful
 * copy. Forwards every `<Button>` prop except `onClick` + `children`, so the
 * caller controls variant, size, className, etc.
 *
 * @example  Bare icon button next to a value
 *   <span>
 *     <code>{token}</code>
 *     <CopyToClipboardButton value={token} aria-label="Copy token" size="icon-xs" variant="ghost" />
 *   </span>
 *
 * @example  Labelled button inside a modal
 *   <CopyToClipboardButton
 *     value={secret}
 *     aria-label="Copy secret"
 *     size="sm"
 *     variant="outline"
 *     label="Copy"
 *     copiedLabel="Copied"
 *   />
 */
export function CopyToClipboardButton({
  value,
  icon = <CopyIcon />,
  copiedIcon = <CheckIcon />,
  label,
  copiedLabel,
  resetMs,
  stopPropagation = true,
  className,
  size = 'icon-xs',
  variant = 'ghost',
  type = 'button',
  ...rest
}: CopyToClipboardButtonProps) {
  const { copied, copy } = useCopyToClipboard(resetMs !== undefined ? { resetMs } : undefined)
  const displayedLabel = copied && copiedLabel !== undefined ? copiedLabel : label

  return (
    <Button
      {...rest}
      type={type}
      size={size}
      variant={variant}
      className={cn(className)}
      onClick={(e) => {
        if (stopPropagation) e.stopPropagation()
        copy(value)
      }}
    >
      {copied ? copiedIcon : icon}
      {displayedLabel}
    </Button>
  )
}
