import {
  Badge,
  Button,
  Checkbox,
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
  Input,
  Switch,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useWebhookEventCatalog } from '../../hooks/use-webhook-endpoints'
import { translatedLabel } from '../../lib/translated-label'
import type { WebhookEndpointFormValues } from '../../schemas/webhook-endpoint'

/**
 * The webhook endpoint form fields — Name / URL / Active toggle / Events
 * picker. Used both by the Create sheet on the index page and the Edit card
 * on the endpoint detail route, so changes stay in sync.
 *
 * Drive submission from the caller — this component is purely the field set,
 * not the form wrapper.
 */
export function WebhookEndpointFormFields({
  form,
}: {
  form: UseFormReturn<WebhookEndpointFormValues>
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <Field>
        <FieldLabel htmlFor="webhook-name">
          {t('admin.fields.webhook_endpoint.name.label')}
        </FieldLabel>
        <Input
          id="webhook-name"
          placeholder={t('admin.fields.webhook_endpoint.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldDescription>{t('admin.fields.webhook_endpoint.name.help')}</FieldDescription>
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="webhook-url">
          {t('admin.fields.webhook_endpoint.url.label')}
        </FieldLabel>
        <Input
          id="webhook-url"
          type="url"
          placeholder={t('admin.fields.webhook_endpoint.url.placeholder')}
          aria-invalid={!!errors.url || undefined}
          {...form.register('url')}
        />
        <FieldError errors={[errors.url]} />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="webhook-active" className="cursor-pointer">
              {t('admin.fields.webhook_endpoint.active.label')}
            </FieldLabel>
            <FieldDescription>{t('admin.fields.webhook_endpoint.active.help')}</FieldDescription>
          </div>
          <Controller
            name="active"
            control={form.control}
            render={({ field }) => (
              <Switch id="webhook-active" checked={field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.webhook_endpoint.subscriptions.label')}</FieldLabel>
        <FieldDescription>{t('admin.fields.webhook_endpoint.subscriptions.help')}</FieldDescription>
        <Controller
          name="subscriptions"
          control={form.control}
          render={({ field }) => <EventPicker value={field.value} onChange={field.onChange} />}
        />
      </Field>
    </>
  )
}

function EventPicker({ value, onChange }: { value: string[]; onChange: (next: string[]) => void }) {
  const { t } = useTranslation()
  const [customEvent, setCustomEvent] = useState('')
  const { data: catalog } = useWebhookEventCatalog()
  const events = catalog?.data ?? []
  const subscribed = new Set(value)
  const declared = new Set(events.map((event) => event.name))
  const customEvents = value.filter((event) => !declared.has(event))

  // A deprecated event is offered only to an endpoint still subscribed to it,
  // so it can be swapped for its replacement but never newly picked.
  const groups = new Map<string, typeof events>()
  for (const event of events) {
    if (event.deprecated && !subscribed.has(event.name)) continue
    const group = groups.get(event.group)
    if (group) group.push(event)
    else groups.set(event.group, [event])
  }

  function toggle(event: string) {
    onChange(value.includes(event) ? value.filter((e) => e !== event) : [...value, event])
  }

  function addCustom() {
    const trimmed = customEvent.trim()
    if (!trimmed || value.includes(trimmed)) return
    onChange([...value, trimmed])
    setCustomEvent('')
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border">
      <div className="border-b border-border bg-muted/30 p-3 text-xs text-muted-foreground">
        {value.length === 0
          ? t('admin.pages.settings.webhooks.events_all')
          : t('admin.pages.settings.webhooks.events_count', { count: value.length })}
      </div>
      <div className="flex max-h-72 flex-col gap-4 overflow-y-auto p-3">
        {[...groups].map(([group, groupEvents]) => (
          <div key={group} className="flex flex-col gap-1">
            <span className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
              {translatedLabel('admin.pages.settings.webhooks.event_groups', group)}
            </span>
            <div className="grid grid-cols-1 gap-1 sm:grid-cols-2">
              {groupEvents.map((event) => {
                const checkboxId = `webhook-event-${event.name.replace(/[^a-z0-9]/gi, '-')}`
                return (
                  <label
                    key={event.name}
                    htmlFor={checkboxId}
                    className="flex cursor-pointer items-center gap-2 rounded p-1 text-sm hover:bg-accent"
                  >
                    <Checkbox
                      id={checkboxId}
                      checked={subscribed.has(event.name)}
                      onCheckedChange={() => toggle(event.name)}
                    />
                    <span className="font-mono text-xs">{event.name}</span>
                    {event.credential && (
                      <Badge variant="outline">
                        {t('admin.pages.settings.webhooks.events_credential')}
                      </Badge>
                    )}
                    {event.deprecated && (
                      <Badge variant="secondary">
                        {t('admin.pages.settings.webhooks.events_deprecated', {
                          event: event.replaced_by,
                        })}
                      </Badge>
                    )}
                  </label>
                )
              })}
            </div>
          </div>
        ))}
        {customEvents.length > 0 && (
          <div className="flex flex-col gap-1">
            <span className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
              {t('admin.pages.settings.webhooks.event_groups.custom')}
            </span>
            <div className="flex flex-wrap gap-1.5">
              {customEvents.map((event) => (
                <Badge key={event} variant="secondary" className="font-mono">
                  {event}
                  <button
                    type="button"
                    onClick={() => toggle(event)}
                    className="ml-1.5 text-muted-foreground hover:text-destructive"
                    aria-label={t('admin.pages.settings.webhooks.events_remove_aria', { event })}
                  >
                    ×
                  </button>
                </Badge>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="flex items-center gap-2 border-t border-border p-3">
        <Input
          placeholder={t('admin.pages.settings.webhooks.events_custom_input_placeholder')}
          value={customEvent}
          onChange={(e) => setCustomEvent(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              addCustom()
            }
          }}
          className="font-mono text-xs"
        />
        <Button type="button" variant="outline" size="sm" onClick={addCustom}>
          {t('admin.actions.add')}
        </Button>
      </div>
    </div>
  )
}
