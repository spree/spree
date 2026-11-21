import { installStaleChunkRecovery } from '@spree/dashboard-core'

// A tab left open across a deploy asks for chunks the new build no longer
// has; reload it onto the current build instead of crashing the page it is
// on. Side-effect import, run once when the shell loads — in hosts that render
// <SellerDashboard> and in hosts that spell out its provider stack alike.
installStaleChunkRecovery()
