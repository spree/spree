import * as R from 'ramda'
import COUNTRY from './country'
import STATE from './state'

export default R.merge(COUNTRY, { states: [STATE] })
