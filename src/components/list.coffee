_ = require 'lodash'
React = require 'react'
Bootstrap = require 'react-bootstrap'

Category = require './category'
Search = require './search'

{DOM} = React

Accordion = React.createFactory Bootstrap.Accordion
Panel = React.createFactory Bootstrap.Panel

module.exports = React.createFactory React.createClass
  getInitialState: ->
    plugins: @props.plugins ? []
    permissions: @props.permissions ? {}
    categorizedPlugins: @categorizePlugins @props.plugins ? []

  togglePlugin: (plugin, permissions = [], additional = []) ->
    if plugin.kerplunk?.dependencies
      console.log 'add deps', plugin.kerplunk.dependencies
      additional = _.unique additional.concat plugin.kerplunk.dependencies
    console.log 'toggle plugin', plugin, additional
    action = if plugin.enabled then 'disable' else 'enable'
    url = "/admin/plugins/#{plugin.name}/#{action}.json"
    console.log url
    data =
      permissions: permissions.join ','
      additional: additional.join ','

    @props.request.post url, data, (err, obj) =>
      console.log 'response', err, obj
      return console.log err if err
      return unless @isMounted()
      newPlugins = obj?.plugins ? @state.plugins
      @setState
        plugins: newPlugins
        permissions: obj.permissions ? @state.permissions
        categorizedPlugins: @categorizePlugins newPlugins
      @props.refreshState()

  # componentWillReceiveProps: (newProps) ->
  #   console.log 'receiving props', newProps?.plugins?
  #   if newProps.plugins and newProps.plugins != @state.plugins
  #     @setState
  #       categorizedPlugins: @categorizePlugins newProps.plugins
  #   @setState
  #     plugins: newProps.plugins ? @state.plugins
  #     permissions: newProps.permissions ? @state.permissions

  categorizePlugins: (plugins = @state.plugins) ->
    all =
      active: {}
      available: {}
    all = _ plugins
      .filter (plugin) -> !plugin.isCore
      .reduce (memo, plugin) ->
        bucket = if plugin.enabled
          memo.active
        else
          memo.available
        categories = _ plugin.keywords
          .filter (keyword) -> /^kp:/.test keyword
          .map (keyword) -> keyword.substring 3
          .value()
        unless categories.length > 0
          categories.push 'Miscellaneous'
        for category in categories
          bucket[category] = [] unless bucket[category]
          bucket[category].push plugin
        memo
      , {active: {}, available: {}}
    all.active = _ all.active
      .map (plugins, name) ->
        name: name
        plugins: _.sortBy plugins, (plugin) ->
          plugin.displayName ? plugin.name
      .sortBy 'name'
      .value()
    all.available = _ all.available
      .map (plugins, name) ->
        name: name
        plugins: _.sortBy plugins, (plugin) ->
          plugin.displayName ? plugin.name
      .sortBy 'name'
      .value()
    # console.log 'all', all
    all

  render: ->
    {active, available} = @state.categorizedPlugins

    DOM.section
      className: 'content'
    ,
      DOM.div
        className: 'row'
      ,
        DOM.div
          className: 'col col-lg-12'
        , Search _.extend {}, @props, @state,
          togglePlugin: @togglePlugin
      DOM.div
        className: 'row'
      ,
        DOM.div
          className: 'plugin-list col-md-6'
        ,
          DOM.h3 null,
            'Active Plugins ('
            _.filter(@state.plugins, (p) -> p.enabled and !p.isCore).length
            ')'
          Accordion
            className: ''
            eventKey: '1'
          , _.map active, (category, index) =>
              Category _.extend {}, @props, @state,
                key: "category-#{category.name}"
                eventKey: String index
                category: category.name
                plugins: category.plugins
                allPlugins: @state.plugins
                togglePlugin: @togglePlugin
        DOM.div
          className: 'plugin-list col-md-6'
        ,
          DOM.h3 null,
            'Available Plugins ('
            _.filter(@state.plugins, (p) -> !p.enabled and !p.isCore).length
            ')'
          Accordion
            className: 'plugin-list'
          , _.map available, (category, index) =>
              Category _.extend {}, @props, @state,
                key: "category-#{category.name}"
                eventKey: String index
                category: category.name
                plugins: category.plugins
                allPlugins: @state.plugins
                togglePlugin: @togglePlugin
        DOM.div
          style:
            clear: 'both'
