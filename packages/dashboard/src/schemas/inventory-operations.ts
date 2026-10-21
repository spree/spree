/** What happens to units still in flight when a shipped transfer is called off. */
export const IN_TRANSIT_RESOLUTIONS = ['restock', 'write_off'] as const

export type InTransitResolution = (typeof IN_TRANSIT_RESOLUTIONS)[number]

/** A transfer whose units have left the source but not all arrived. */
export function isInFlight(status: string): boolean {
  return status === 'in_transit' || status === 'partially_received'
}

/** Nothing more will arrive on a document in one of these. */
export function isClosed(status: string): boolean {
  return status === 'received' || status === 'over_received' || status === 'canceled'
}
