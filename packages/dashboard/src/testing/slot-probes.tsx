// Slot probes for the end-to-end suite — loaded only when the build sets
// VITE_E2E_SLOT_PROBES=1 (see main.tsx), never in a shipped dashboard. Each
// probe marks where a slot renders, and the host-form ones bind a field that
// saves through the page, so a spec proves a slot both renders and persists.
// The strings are test fixtures, so they are not translated.
//
// The fields write into `metadata`, which the e2e server permits on the
// records involved (e2e/global-setup.ts) the way an extension permits its
// own columns.
import {
  defineDashboardPlugin,
  type NewMediaEntry,
  type SlotEntry,
  useHostForm,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  ContextMenuItem,
  Field,
  FieldLabel,
  Input,
} from '@spree/dashboard-ui'
import type { ComponentType } from 'react'

function probe<TContext>(component: ComponentType<TContext>): SlotEntry[] {
  return [{ id: 'e2e-probe', component: component as never }]
}

function marker(slot: string) {
  return probe(({ mode }: { mode?: string }) => (
    <Card>
      <CardContent className="text-muted-foreground text-sm">
        Slot probe: {slot}
        {mode ? ` (${mode})` : ''}
      </CardContent>
    </Card>
  ))
}

function HostField({ label, name }: { label: string; name: string }) {
  const form = useHostForm()
  const id = `probe-${name.replaceAll('.', '-')}`

  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <Input id={id} {...form.register(name)} />
    </Field>
  )
}

function hostField(label: string, key: string) {
  return probe(({ fieldPrefix }: { fieldPrefix?: string }) => (
    <HostField
      label={label}
      name={fieldPrefix ? `${fieldPrefix}.metadata.${key}` : `metadata.${key}`}
    />
  ))
}

const metadataField = {
  name: 'metadata',
  from: (record: unknown) =>
    (record as { metadata?: Record<string, unknown> } | null)?.metadata ?? {},
}

const PROBE_VIDEO_URL = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'

defineDashboardPlugin({
  formFields: {
    media: [metadataField],
    'product.media': [metadataField],
    'product.variant': [metadataField],
  },
  slots: {
    'media.form_fields': hostField('Probe library credit', 'e2e_credit'),
    'media.context_menu': probe(() => <ContextMenuItem>Probe menu action</ContextMenuItem>),
    'product.form_main': marker('product.form_main'),
    'product.form_sidebar': marker('product.form_sidebar'),
    'product.media.form_fields': hostField('Probe media credit', 'e2e_credit'),
    'product.media.actions': probe(
      ({ addMedia }: { addMedia: (entries: NewMediaEntry[]) => void }) => (
        <Button
          type="button"
          variant="outline"
          onClick={() =>
            addMedia([{ media_type: 'external_video', external_video_url: PROBE_VIDEO_URL }])
          }
        >
          Probe attach video
        </Button>
      ),
    ),
    'product.variant.form_fields': hostField('Probe variant code', 'e2e_code'),
  },
})
