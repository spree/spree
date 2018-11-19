import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { compose, join, juxt, toUpper, head, tail } from 'ramda'

import IconClose from 'react-feather/dist/icons/chevron-right'
import IconOpen from 'react-feather/dist/icons/chevron-down'

export default class Sidebar extends React.Component {
  static propTypes = {
    nav: PropTypes.array.isRequired,
    activeSection: PropTypes.string
  }

  state = {
    openSection: null
  }

  capitalizeSectionTitle = compose(
    join(''),
    juxt([
      compose(
        toUpper,
        head
      ),
      tail
    ])
  )

  sectionIsOpen = section => {
    return (
      section === this.state.openSection || section === this.props.activeSection
    )
  }

  _openSection = section => {
    return this.setState({ openSection: section })
  }

  _closeSection = () => {
    return this.setState({ openSection: null })
  }

  render() {
    return (
      <aside>
        <nav>
          <ul className="list ma0 pl0">
            {this.props.nav.map((item, index) => (
              <li key={index}>
                <h3 className="flex items-center mt0">
                  {this.sectionIsOpen(item.section) ? (
                    <IconOpen
                      className="pointer"
                      onClick={() => this._closeSection()}
                    />
                  ) : (
                    <IconClose
                      className="pointer"
                      onClick={() => this._openSection(item.section)}
                    />
                  )}
                  <span>{this.capitalizeSectionTitle(item.section)}</span>
                </h3>
                <ul
                  className={`list pl0 ml3 mb4 ${
                    this.sectionIsOpen(item.section) ? '' : 'dn'
                  }`}
                >
                  {item.edges.map((edge, index) => (
                    <li key={index}>
                      <Link
                        to={edge.node.fields.slug}
                        activeClassName="green"
                        className="link gray db mv2"
                      >
                        {edge.node.frontmatter.title}
                      </Link>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        </nav>
      </aside>
    )
  }
}
