import {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldLabel,
  FieldTitle,
  Input,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import type { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useChannels } from '../../../hooks/use-channels'

// The name field is identical across the create and edit sheets; both register
// a `name` string field with the same label/placeholder/validation.
export function ApiKeyNameField({
  id,
  register,
  error,
}: {
  id: string
  register: ReturnType<typeof useForm<{ name: string }>>['register']
  error?: { message?: string }
}) {
  const { t } = useTranslation()
  return (
    <Field>
      <FieldLabel htmlFor={id}>{t('admin.fields.api_key.name.label')}</FieldLabel>
      <Input
        id={id}
        autoFocus
        placeholder={t('admin.fields.api_key.name.placeholder')}
        aria-invalid={!!error || undefined}
        {...register('name')}
      />
      <FieldError errors={[error]} />
    </Field>
  )
}

export function FormErrorBanner({ message }: { message?: string }) {
  if (!message) return null
  return (
    <p className="text-sm text-destructive" role="alert">
      {message}
    </p>
  )
}

export function KeyTypeChoice({
  value,
  title,
  description,
}: {
  value: 'publishable' | 'secret'
  title: string
  description: string
}) {
  return (
    <FieldLabel>
      <Field orientation="horizontal">
        <FieldContent>
          <FieldTitle>{title}</FieldTitle>
          <FieldDescription>{description}</FieldDescription>
        </FieldContent>
        <RadioGroupItem value={value} />
      </Field>
    </FieldLabel>
  )
}

// Sentinel for the "All channels" (store-wide) option. Base UI's `<Select>`
// treats an empty string value as "no selection" and shows the placeholder, so
// the store-wide choice carries this non-empty value and is mapped back to `''`
// (the schema's store-wide value) at the boundary.
const ALL_CHANNELS = '__all__'

// Channel binding picker for publishable keys. Unlike the shared
// `<ChannelSelect>`, the first option is "All channels" (store-wide) so a key
// can be left unbound, which is the default. Emits `''` for store-wide and a
// prefixed `ch_…` for a bound channel.
export function ChannelBindingSelect({
  id,
  value,
  onChange,
}: {
  id: string
  value: string
  onChange: (channelId: string) => void
}) {
  const { t } = useTranslation()
  const { data } = useChannels()
  const channels = data?.data ?? []

  const allChannelsLabel = t('admin.fields.api_key.channel.all_channels')

  return (
    <Select
      value={value === '' ? ALL_CHANNELS : value}
      onValueChange={(v) => onChange(v === ALL_CHANNELS ? '' : v)}
    >
      <SelectTrigger id={id}>
        {/* Base UI's `<SelectValue>` renders the raw value (the prefixed ID);
            the children render-prop resolves the channel name from the cached
            list so the trigger matches the selected item. */}
        <SelectValue>
          {(v) =>
            v === ALL_CHANNELS
              ? allChannelsLabel
              : (channels.find((c) => c.id === v)?.name ?? allChannelsLabel)
          }
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={ALL_CHANNELS}>{allChannelsLabel}</SelectItem>
        {channels.map((c) => (
          <SelectItem key={c.id} value={c.id}>
            {c.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
