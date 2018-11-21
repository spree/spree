import * as React from 'react'
import PropTypes from 'prop-types'
import SyntaxHighlighter from 'react-syntax-highlighter'
import syntaxTheme from 'react-syntax-highlighter/dist/esm/styles/prism/solarizedlight'

import IMAGE from '../../data/image'
import OPTION_TYPE from '../../data/option_type'
import OPTION_VALUE from '../../data/option_value'
import STOCK_ITEM from '../../data/stock_item'
import USER from '../../data/user'
import VARIANT from '../../data/variant'
import ADDRESS from '../../data/address'

const DATA_SAMPLES = {
  address: ADDRESS,
  image: IMAGE,
  option_type: OPTION_TYPE,
  option_value: OPTION_VALUE,
  stock_item: STOCK_ITEM,
  user: USER,
  variant: VARIANT
}

const Json = ({ sample }) => (
  <div>
    <SyntaxHighlighter language="json" style={syntaxTheme}>
      {JSON.stringify(DATA_SAMPLES[sample], null, 2)}
    </SyntaxHighlighter>
  </div>
)

Json.propTypes = {
  sample: PropTypes.oneOf(Object.keys(DATA_SAMPLES))
}

export default Json
