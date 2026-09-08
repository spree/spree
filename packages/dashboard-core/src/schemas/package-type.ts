import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'
import type { PanelPackageType, PanelPackageTypeCreateParams } from '../api-client'

// The vocabulary the server validates against; typing anything else could
// only fail on save.
export const PACKAGE_TYPE_KINDS = ['box', 'envelope', 'carton', 'pallet', 'container'] as const
export const PACKAGE_DIMENSION_UNITS = ['mm', 'cm', 'in', 'ft'] as const
export const PACKAGE_WEIGHT_UNITS = ['g', 'kg', 'lb', 'oz'] as const

export type PackageTypeKind = (typeof PACKAGE_TYPE_KINDS)[number]
export type PackageDimensionUnit = (typeof PACKAGE_DIMENSION_UNITS)[number]
export type PackageWeightUnit = (typeof PACKAGE_WEIGHT_UNITS)[number]

// Blank is how a merchant says "not measured", so every number is optional
// and an empty string reaches the API as null rather than zero — a box
// recorded as zero long, zero wide is not the same as one nobody measured.
const optionalNumber = z
  .union([z.string(), z.number()])
  .optional()
  // `NaN >= 0` is already false, so the comparison alone rejects garbage.
  .refine((value) => value === '' || value === undefined || Number(value) >= 0, {
    error: () => i18n.t('admin.package_types.validation.non_negative'),
  })

export const packageTypeFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('package_type.name') }),
  kind: z.enum(PACKAGE_TYPE_KINDS),
  length: optionalNumber,
  width: optionalNumber,
  height: optionalNumber,
  dimensions_unit: z.enum(PACKAGE_DIMENSION_UNITS).optional(),
  weight: optionalNumber,
  max_weight: optionalNumber,
  weight_unit: z.enum(PACKAGE_WEIGHT_UNITS).optional(),
  default: z.boolean().optional(),
})

export type PackageTypeFormValues = z.input<typeof packageTypeFormSchema>

export const PACKAGE_TYPE_DEFAULTS: PackageTypeFormValues = {
  name: '',
  kind: 'box',
  length: '',
  width: '',
  height: '',
  dimensions_unit: 'cm',
  weight: '',
  max_weight: '',
  weight_unit: 'kg',
  default: false,
}

/**
 * Blank erases a measurement, so it has to reach the API as an explicit null;
 * undefined would leave whatever was recorded before untouched.
 */
export function packageTypeFormValuesToParams(
  values: PackageTypeFormValues,
): PanelPackageTypeCreateParams {
  const measurement = (value: string | number | undefined) =>
    value === '' || value === undefined ? null : Number(value)

  return {
    name: values.name,
    kind: values.kind,
    length: measurement(values.length),
    width: measurement(values.width),
    height: measurement(values.height),
    weight: measurement(values.weight),
    max_weight: measurement(values.max_weight),
    dimensions_unit: values.dimensions_unit,
    weight_unit: values.weight_unit,
    default: values.default,
  }
}

export function packageTypeToFormValues(packageType: PanelPackageType): PackageTypeFormValues {
  return {
    name: packageType.name,
    kind: (packageType.kind ?? 'box') as PackageTypeKind,
    length: packageType.length ?? '',
    width: packageType.width ?? '',
    height: packageType.height ?? '',
    dimensions_unit: (packageType.dimensions_unit ?? 'cm') as PackageDimensionUnit,
    weight: packageType.weight ?? '',
    max_weight: packageType.max_weight ?? '',
    weight_unit: (packageType.weight_unit ?? 'kg') as PackageWeightUnit,
    default: packageType.default ?? false,
  }
}
