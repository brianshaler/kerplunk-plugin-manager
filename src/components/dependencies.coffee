_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.div null,
      DOM.h4 null, 'Required plugins:'
      _.map @props.dependencies, (dep) ->
        DOM.div
          key: "#{dep}"
        ,
          DOM.input
            type: 'checkbox'
            checked: true
            onChange: (e) -> e.preventDefault()
            disabled: true
          ' '
          DOM.label null, dep
