import { Input, RichTextEditor, Switch, Textarea } from '@spree/dashboard-ui'
import { type Control, Controller } from 'react-hook-form'
import { useTranslation } from '@/lib/i18n'

type FieldType = 'short_text' | 'long_text' | 'rich_text' | 'number' | 'boolean' | 'json'

interface ValueInputProps {
  control: Control<Record<string, unknown>>
  name: string
  fieldType: FieldType
  id?: string
}

export function ValueInput({ control, name, fieldType, id }: ValueInputProps) {
  const { t } = useTranslation()
  return (
    <Controller
      name={name}
      control={control}
      render={({ field }) => {
        switch (fieldType) {
          case 'short_text':
            return (
              <Input
                id={id}
                value={(field.value as string | null | undefined) ?? ''}
                onChange={field.onChange}
                onBlur={field.onBlur}
              />
            )
          case 'long_text':
            return (
              <Textarea
                id={id}
                rows={4}
                value={(field.value as string | null | undefined) ?? ''}
                onChange={field.onChange}
                onBlur={field.onBlur}
              />
            )
          case 'rich_text':
            return (
              <RichTextEditor
                value={(field.value as string | null | undefined) ?? ''}
                onChange={field.onChange}
              />
            )
          case 'number':
            return (
              <Input
                id={id}
                type="number"
                step="any"
                value={field.value === null || field.value === undefined ? '' : String(field.value)}
                onChange={(e) => {
                  const v = e.target.value
                  field.onChange(v === '' ? null : Number(v))
                }}
                onBlur={field.onBlur}
              />
            )
          case 'boolean':
            return (
              <Switch id={id} checked={Boolean(field.value)} onCheckedChange={field.onChange} />
            )
          case 'json':
            return (
              <Textarea
                id={id}
                rows={6}
                className="font-mono text-xs"
                placeholder={t('admin.components.custom_fields.json_placeholder')}
                value={
                  field.value === null || field.value === undefined
                    ? ''
                    : typeof field.value === 'string'
                      ? field.value
                      : JSON.stringify(field.value, null, 2)
                }
                onChange={(e) => field.onChange(e.target.value)}
                onBlur={(e) => {
                  field.onBlur()
                  // Try to parse on blur so the form holds an object, not a string
                  const v = e.target.value.trim()
                  if (!v) {
                    field.onChange(null)
                    return
                  }
                  try {
                    field.onChange(JSON.parse(v))
                  } catch {
                    // leave as raw string; submit will surface the server error
                  }
                }}
              />
            )
        }
      }}
    />
  )
}
