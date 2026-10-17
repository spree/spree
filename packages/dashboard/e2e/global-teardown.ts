import { ASYNC_JOBS_INITIALIZER, RAILS_PID_FILE, TEST_INTEGRATION_INITIALIZER } from './paths'
import { rmIfExists, stopRails } from './rails'

export default async function globalTeardown() {
  rmIfExists(ASYNC_JOBS_INITIALIZER)
  rmIfExists(TEST_INTEGRATION_INITIALIZER)
  await stopRails(RAILS_PID_FILE)
}
