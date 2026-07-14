import { type FieldValues, type UseFormReturn, useFormContext } from 'react-hook-form'

/**
 * The react-hook-form instance of the built-in resource form a slot widget is
 * rendered inside (e.g. the product detail form for `product.form_sidebar`).
 * Fields registered against it — `form.register(...)` or `<Controller>` —
 * hydrate, dirty-track, and persist through the host page's own Save button;
 * the widget ships no save logic of its own.
 *
 * Only forms that opt in provide a host form (they wrap themselves in RHF's
 * `FormProvider`). Slots on pages without a page-wide form (orders,
 * customers) have none — calling this there throws. Use
 * `useOptionalHostForm()` for widgets that render in both kinds of context.
 */
export function useHostForm<
  TFieldValues extends FieldValues = FieldValues,
>(): UseFormReturn<TFieldValues> {
  const form = useFormContext<TFieldValues>()
  if (!form) {
    throw new Error(
      'useHostForm() must be rendered inside a resource form that exposes its form context ' +
        '(e.g. a product.form_sidebar slot widget). This page has no host form — ' +
        'use useOptionalHostForm() and fall back to your own state + API save.',
    )
  }
  return form
}

/** Like {@link useHostForm}, but returns `null` when there is no host form. */
export function useOptionalHostForm<
  TFieldValues extends FieldValues = FieldValues,
>(): UseFormReturn<TFieldValues> | null {
  return useFormContext<TFieldValues>() ?? null
}
