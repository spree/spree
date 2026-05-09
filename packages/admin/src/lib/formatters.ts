export function formatPrice(
  price: { amount?: string; currency?: string; display?: string } | null,
) {
  if (!price) return '—'
  return price.display ?? `${price.currency} ${price.amount}`
}
