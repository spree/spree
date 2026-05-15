import { isMaskedSecret } from '@spree/admin-sdk'
import { EyeIcon, EyeOffIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Field, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'

interface SecretInputProps {
  id: string
  label: string
  value: unknown
  onChange: (value: unknown) => void
  /**
   * When true, a value that arrives carrying the server's mask token
   * (`••••3K9z`) is treated as "already stored" — show the masked badge
   * with a Replace button instead of an editable input. Cancel restores
   * the original masked value so the backend's round-trip guard keeps
   * the existing secret.
   */
  redactWhenMasked?: boolean
  /** Replaces the default "Stored on the server. Click Replace to rotate." caption. */
  helpText?: string
  /** Placeholder for the editable input — only shown when not redacted. */
  placeholder?: string
}

/**
 * Stripe-style credential field. When the value comes back from the API
 * masked (`••••3K9z`), display it as a read-only badge with a "Replace"
 * button. Replace switches to a password input pre-filled empty so the
 * admin opts in to rotation; Cancel reverts to the masked badge so the
 * next save preserves the existing secret via the backend's masked
 * round-trip guard.
 *
 * Domain-agnostic — used by `<PreferencesForm>` for `:password`-typed
 * preferences, but also suitable for any other secret that round-trips
 * through the API (webhook signing keys, OAuth client secrets, etc).
 */
export function SecretInput({
  id,
  label,
  value,
  onChange,
  redactWhenMasked = false,
  helpText,
  placeholder,
}: SecretInputProps) {
  const storedMask = isMaskedSecret(value) ? (value as string) : null
  // Track the original mask so Cancel restores it verbatim — the backend's
  // round-trip guard recognises the token and keeps the existing secret.
  const initialMaskRef = useRef<string | null>(storedMask)
  const [replacing, setReplacing] = useState(false)
  const [revealed, setRevealed] = useState(false)

  if (redactWhenMasked && storedMask && !replacing) {
    return (
      <Field>
        <FieldLabel htmlFor={id}>{label}</FieldLabel>
        <div className="flex items-center gap-2">
          {/* Match `<Input>`'s metrics exactly (min-h-9, py-1.5 px-2.5, rounded-lg border)
              so toggling between badge ↔ input doesn't reflow the field. */}
          <div className="flex min-h-9 w-full min-w-0 items-center rounded-lg border border-border bg-muted/40 px-2.5 py-1.5 shadow-xs">
            <span className="font-mono text-sm tabular-nums text-muted-foreground" id={id}>
              {storedMask}
            </span>
          </div>
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => {
              initialMaskRef.current = storedMask
              onChange('')
              setReplacing(true)
            }}
          >
            Replace
          </Button>
        </div>
        <span className="text-xs text-muted-foreground">
          {helpText ?? 'Stored on the server. Click Replace to rotate.'}
        </span>
      </Field>
    )
  }

  // Editable input — either an empty form (create), an unredacted field
  // (server didn't ship a mask), or the admin clicked Replace.
  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Input
            id={id}
            type={revealed ? 'text' : 'password'}
            autoComplete="new-password"
            placeholder={replacing ? 'New value' : placeholder}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
            // Keep room on the right edge so typed values don't run under the eye button.
            className="pr-9"
          />
          <button
            type="button"
            aria-label={revealed ? 'Hide value' : 'Show value'}
            aria-pressed={revealed}
            onClick={() => setRevealed((v) => !v)}
            className="absolute inset-y-0 right-0 flex items-center px-2.5 text-muted-foreground hover:text-foreground"
          >
            {revealed ? <EyeOffIcon className="size-4" /> : <EyeIcon className="size-4" />}
          </button>
        </div>
        {replacing && initialMaskRef.current && (
          <Button
            type="button"
            size="sm"
            variant="ghost"
            onClick={() => {
              onChange(initialMaskRef.current)
              setReplacing(false)
              setRevealed(false)
            }}
          >
            Cancel
          </Button>
        )}
      </div>
    </Field>
  )
}
