import { FIRST_RUN_RAILS_PID_FILE } from '../paths'
import { stopRails } from '../rails'

export default async function globalTeardown() {
  await stopRails(FIRST_RUN_RAILS_PID_FILE)
}
