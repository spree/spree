import { ASYNC_JOBS_INITIALIZER, RAILS_PID_FILE } from './paths'
import { rmIfExists, stopRails } from './rails'

export default async function globalTeardown() {
  rmIfExists(ASYNC_JOBS_INITIALIZER)
  stopRails(RAILS_PID_FILE)
}
