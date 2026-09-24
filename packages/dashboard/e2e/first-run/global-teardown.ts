import { FIRST_RUN_RAILS_PID_FILE } from '../paths'
import { stopRails } from '../rails'

export default async function globalTeardown() {
  stopRails(FIRST_RUN_RAILS_PID_FILE)
}
