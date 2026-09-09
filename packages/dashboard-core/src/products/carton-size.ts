import type { PanelPackageType } from '../api-client'

/**
 * A carton's size, as the merchant recorded it — for telling two similarly
 * named cartons apart wherever one is chosen.
 *
 * Null unless all three measurements are there: half a box is not a size. The
 * unit travels with the numbers because the same three read as inches rather
 * than centimeters describe a box sixteen times the volume.
 */
export function cartonSize(carton: PanelPackageType): string | null {
  const { length, width, height, dimensions_unit } = carton
  if (length == null || width == null || height == null) return null

  // Decimals arrive as strings, so `60.0` would read back as a precision the
  // merchant never typed.
  const trim = (value: string) => String(Number(value))

  return `${trim(length)} × ${trim(width)} × ${trim(height)} ${dimensions_unit ?? ''}`.trim()
}
