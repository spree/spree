import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import { Field, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'

// Server masks stored secrets as `••••…` on read so admins can see "yes,
// something is stored" without exposing the actual value. Detecting that
// prefix tells us whether the field is round-tripping the existing secret
// (the backend has a guard that ignores writes still carrying the mask).
const PREFERENCE_MASK_TOKEN = '••••'
function isMaskedSecret(value: unknown): value is string {
  return typeof value === 'string' && value.startsWith(PREFERENCE_MASK_TOKEN)
}

interface SecretInputProps {
  id: string
  label: string
  value: unknown
  onChange: (value: unknown) => void
  /**
   * @deprecated Masked values always render as the stored badge — there is
   * nothing to reveal, since the server never sends the secret. Retained so
   * existing callers keep compiling; the prop has no effect.
   */
  redactWhenMasked?: boolean
  /** Replaces the default "Stored on the server. Click Replace to rotate." caption. */
  helpText?: string
  /** Placeholder for the editable input — only shown when not redacted. */
  placeholder?: string
}

/**
 * Stripe-style credential field. A stored secret arrives from the API as a
 * mask (`••••3K9z`) and renders as a read-only badge with a "Replace"
 * button — never as an input, and never with a reveal toggle, because the
 * server does not send the secret and there is nothing to unhide. Replace
 * switches to an empty password input so the admin opts in to rotation;
 * Cancel reverts to the badge so the next save preserves the existing
 * secret via the backend's masked round-trip guard.
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
  helpText,
  placeholder,
}: SecretInputProps) {
  const { t } = useTranslation()
  const storedMask = isMaskedSecret(value) ? value : null
  // Captured at click time so Cancel can restore the original mask even
  // after `onChange('')` has cleared the parent value.
  const [pendingMask, setPendingMask] = useState<string | null>(null)
  const replacing = pendingMask !== null

  // A stored secret always renders as the badge: the server sent a mask,
  // not the value, so there is nothing a reveal toggle could show.
  if (storedMask && !replacing) {
    return (
      <Field>
        <FieldLabel htmlFor={id}>{label}</FieldLabel>
        <div className="flex items-center gap-2">
          <div className="flex min-h-8 w-full min-w-0 items-center rounded-lg border border-border bg-muted/40 px-2.5 py-1.5">
            <span className="font-mono text-sm tabular-nums text-muted-foreground" id={id}>
              {storedMask}
            </span>
          </div>
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => {
              setPendingMask(storedMask)
              onChange('')
            }}
          >
            {t('admin.components.secret_input.replace')}
          </Button>
        </div>
        <span className="text-xs text-muted-foreground">
          {helpText ?? t('admin.components.secret_input.stored_help')}
        </span>
      </Field>
    )
  }

  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <div className="flex items-center gap-2">
        <Input
          id={id}
          type="password"
          autoComplete="new-password"
          placeholder={
            replacing ? t('admin.components.secret_input.new_value_placeholder') : placeholder
          }
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          className="flex-1"
        />
        {replacing && (
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => {
              onChange(pendingMask)
              setPendingMask(null)
            }}
          >
            {t('admin.actions.cancel')}
          </Button>
        )}
      </div>
    </Field>
  )
}
