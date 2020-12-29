import * as R from 'ramda'

import TAXON from './taxon'
import SECONDARY_TAXON from './secondary_taxon'

export default R.merge(TAXON, { taxons: [SECONDARY_TAXON] })
