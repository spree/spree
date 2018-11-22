import * as React from 'react'
import PropTypes from 'prop-types'
import SyntaxHighlighter from 'react-syntax-highlighter'
import syntaxTheme from 'react-syntax-highlighter/dist/esm/styles/prism/solarizedlight'
import * as R from 'ramda'

import IMAGE from '../../data/image'
import OPTION_TYPE from '../../data/option_type'
import OPTION_VALUE from '../../data/option_value'
import STOCK_ITEM from '../../data/stock_item'
import USER from '../../data/user'
import VARIANT from '../../data/variant'
import ADDRESS from '../../data/address'
import NEW_ORDER_SHOW from '../../data/new_order_show'
import LINE_ITEM from '../../data/line_item'
import ORDER_FAILED_TRANSITION from '../../data/order_failed_transition'
import COUNTRY_WITH_STATE from '../../data/country_with_state'
import COUNTRIES from '../../data/countries'

const DATA_SAMPLES = {
  address: ADDRESS,
  image: IMAGE,
  option_type: OPTION_TYPE,
  option_value: OPTION_VALUE,
  stock_item: STOCK_ITEM,
  user: USER,
  variant: VARIANT,
  new_order_show: NEW_ORDER_SHOW,
  line_item: LINE_ITEM,
  order_failed_transition: ORDER_FAILED_TRANSITION,
  country_with_state: COUNTRY_WITH_STATE,
  countries: COUNTRIES
}

export default class Json extends React.Component {
  static propTypes = {
    sample: PropTypes.oneOf(Object.keys(DATA_SAMPLES)),
    merge: PropTypes.string
  }

  normalizeJson = (sample, merge) => {
    let json = DATA_SAMPLES[this.props.sample]

    if (!R.isNil(merge)) {
      json = R.merge(json, JSON.parse(merge))
    } else {
      json = DATA_SAMPLES[this.props.sample]
    }

    return JSON.stringify(json, null, 2)
  }

  render() {
    return (
      <div>
        <SyntaxHighlighter language="json" style={syntaxTheme}>
          {this.normalizeJson(this.props.sample, this.props.merge)}
        </SyntaxHighlighter>
      </div>
    )
  }
}
