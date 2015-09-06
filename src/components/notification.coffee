React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    {data} = @props.notification

    DOM.div
      className: 'notification-multiline'
    ,
      DOM.div
        className: 'notification-line1'
      ,
        data.text
      DOM.div
        className: 'notification-line2'
      ,
        'todo: stuff'
