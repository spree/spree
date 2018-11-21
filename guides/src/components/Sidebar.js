import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import * as R from 'ramda'

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

  capitalizeSectionTitle = R.compose(
    R.join(''),
    R.juxt([
      R.compose(
        R.toUpper,
        R.head
      ),
      R.tail
    ])
  )

  sectionIsOpen = section => {
    return R.or(
      R.equals(section, this.state.openSection),
      R.equals(section, this.props.activeSection)
    )
  }

  _toggleSection = section => {
    this.setState(prevState => {
      if (prevState.openSection !== section) {
        return { openSection: section }
      } else if (prevState.openSection !== null) {
        console.log('2')
        return { openSection: null }
      } else {
        console.log('3')
        return { openSection: null }
      }
    })
  }

  normalizeNavBlock = block => {
    const nav = []

    block.map(item => {
      if (!item.node.fields.isIndex) {
        nav.push({
          title: item.node.frontmatter.title,
          url: item.node.fields.slug
        })
      }
    })

    return nav
  }

  navBlockIndex = block => {
    const hasIndex = item => item.node.fields.isIndex === true
    return R.filter(hasIndex, block)
  }

  getNavBlockIndexSlug = block =>
    this.navBlockIndex(block)[0]['node']['fields']['slug']

  render() {
    return (
      <aside className="mt4">
        <nav>
          <ul className="list ma0 pl0">
            {this.props.nav.map((item, index) => (
              <React.Fragment key={index}>
                {R.length(this.normalizeNavBlock(item.edges)) > 0 && (
                  <li key={index}>
                    <h3 className="flex items-center mt0 fw5">
                      {this.sectionIsOpen(item.section) ? (
                        <IconOpen
                          className="pointer moon-gray"
                          onClick={() => this._toggleSection(item.section)}
                        />
                      ) : (
                        <IconClose
                          className="pointer moon-gray"
                          onClick={() => this._toggleSection(item.section)}
                        />
                      )}

                      {R.length(this.navBlockIndex(item.edges)) > 0 ? (
                        <Link
                          to={this.getNavBlockIndexSlug(item.edges)}
                          activeClassName="green"
                          className="link black db fw5"
                        >
                          {this.capitalizeSectionTitle(item.section)}
                        </Link>
                      ) : (
                        <span
                          className="pointer"
                          onClick={() => this._toggleSection(item.section)}
                        >
                          {this.capitalizeSectionTitle(item.section)}
                        </span>
                      )}
                    </h3>
                    <ul
                      className={`list pl2 ml3 mb4 ${
                        this.sectionIsOpen(item.section) ? '' : 'dn'
                      }`}
                    >
                      {this.normalizeNavBlock(item.edges).map((item, index) => (
                        <li key={index}>
                          <Link
                            to={item.url}
                            activeClassName="green"
                            className="link gray db mv2"
                          >
                            {item.title}
                          </Link>
                        </li>
                      ))}
                    </ul>
                  </li>
                )}
              </React.Fragment>
            ))}
          </ul>
        </nav>
      </aside>
    )
  }
}
