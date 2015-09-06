_ = require 'lodash'
React = require 'react'

Dependencies = require './dependencies'
Permissions = require './permissions'
Recommendations = require './recommendations'

{DOM} = React

flatten = (obj, prefix = []) ->
  results = []
  for k, v of obj
    newPrefix = prefix.concat k
    if v instanceof Array
      for val in v
        results.push newPrefix.concat(val).join('.')
    else if typeof v is 'object'
      results = results.concat flatten v, newPrefix
    else
      results.push newPrefix.concat(v).join('.')
  _.flatten results


module.exports = React.createFactory React.createClass
  getInitialState: ->
    granted = @flatPermissions if @props.plugin.enabled then @props else null
    granted = _ granted
      .map (permission) ->
        permission.replace /\.true$/, ''
      .unique()
      .value()

    expanded: false
    installing: false
    uninstalling: false
    requestedPermissions: @flatPermissions()
    grantedPermissions: granted
    recommended: @props.plugin.kerplunk?.recommended ? []

  componentWillReceiveProps: (newProps) ->
    if @state.installing and newProps.plugin?.enabled
      @setState
        installing: false
    if @state.uninstalling and newProps.plugin?.enabled == false
      @setState
        uninstalling: false

  onToggleEnabled: (e) ->
    e.preventDefault()
    @props.togglePlugin @props.plugin, @state.grantedPermissions, @state.recommended
    if @props.plugin.enabled
      @setState
        uninstalling: true
    else
      @setState
        installing: true

  onToggleExpanded: (e) ->
    e.preventDefault()
    @setState
      expanded: !@state.expanded

  togglePermission: (key) ->
    (e) =>
      console.log 'permission', key, e.target.checked
      granted = @state.grantedPermissions
      if e.target.checked
        granted = _.unique granted.concat key
      else
        granted = _.filter granted, (k) -> k != key
      console.log 'orig', @state.grantedPermissions
      console.log 'granted', granted
      @setState
        grantedPermissions: granted

  toggleRecommendation: (name) ->
    (e) =>
      recs = @state.recommended
      if e.target.checked
        recs = _.unique recs.concat name
      else
        recs = _.filter recs, (r) -> r != name
      @setState
        recommended: recs

  toggleRecommendAll: (e) ->
    recs = if e.target.checked
      @props.plugin.kerplunk?.recommended
    else
      []
    @setState
      recommended: recs

  flatPermissions: (kp = @props.plugin.kerplunk) ->
    list = kp?.permissionsList ? []
    if kp?.permissions
      list = list.concat flatten kp.permissions
    _ list
      .map (permission) ->
        permission.replace /\.true$/, ''
      .unique()
      .sort()
      .value()

  render: ->
    enabled = @props.plugin.enabled
    installed = !!_.find @props.allPlugins, (plugin) =>
      plugin.name == @props.plugin.name
    enableable = true
    if installed and !enabled and @props.plugin.kerplunk?.dependencies
      for dep in @props.plugin.kerplunk.dependencies
        found = _.find @props.allPlugins, (plugin) ->
          plugin.name == dep and (plugin.enabled or plugin.isCore)
        # console.log 'not found', dep unless found
        # unless found
        #   console.log _.pluck @props.allPlugins, 'name'
        enableable = false unless found
    installing = @state.installing
    uninstalling = @state.uninstalling

    buttonText = if installing
      'installing..'
    else if uninstalling
      'disabling..'
    else if enabled
      'disable'
    else if installed
      'enable'
    else
      'install'

    buttonClass = if installing or uninstalling or buttonText == 'disable'
      'btn-default'
    else
      'btn-success'
    buttonClasses = ['btn', buttonClass]

    permissions = _.map @state.requestedPermissions, (name) =>
      name: name
      granted: !!(_.find @state.grantedPermissions, (n) -> n == name)

    keyPrefix = "plugin-#{@props.plugin.name}"

    DOM.div
      className: "plugin-toggle #{if @props.plugin.enabled then 'plugin-enabled' else 'plugin-disabled'}"
    ,
      DOM.div
        className: 'toggle-button'
      ,
        DOM.a
          href: "/admin/plugins/#{@props.plugin.name}/#{if @props.plugin.enabled then 'disable' else 'enable'}.json?additional=#{@state.recommended.join ','}"
          className: buttonClasses.join ' '
          onClick: @onToggleEnabled
          disabled: (true if installing or uninstalling)
        , (@props.buttonText ? buttonText)
      DOM.h3 null, @props.plugin.displayName
      DOM.em null, if installed then 'installed' else 'not installed'
      DOM.p null, @props.plugin.description
      if @state.expanded
        DOM.div null,
          if @props.plugin.kerplunk?.dependencies?.length > 0
            Dependencies
              dependencies: @props.plugin.kerplunk.dependencies
              enabled: enabled
          else
            null

          if permissions.length > 0
            Permissions
              permissions: permissions
              keyPrefix: keyPrefix
              togglePermission: @togglePermission
              enabled: enabled
          else
            null

          if @props.plugin.kerplunk?.recommended?.length > 0
            Recommendations
              recommended: @props.plugin.kerplunk.recommended
              selected: @state.recommended
              toggleRecommendation: @toggleRecommendation
              enabled: enabled
          else
            null

          DOM.a
            href: "/admin/plugins"
            className: 'btn'
            onClick: @onToggleExpanded
          , 'close'
      else
        DOM.div null,
          if @props.plugin.kerplunk?.recommended?.length > 0 and !enabled
            DOM.div null,
              DOM.input
                type: 'checkbox'
                id: "#{keyPrefix}-include-recommended"
                checked: @state.recommended.length == @props.plugin.kerplunk?.recommended?.length
                onChange: @toggleRecommendAll
              ' '
              DOM.label
                htmlFor: "#{keyPrefix}-include-recommended"
              , 'include all recommended plugins'
          else
            null
          DOM.a
            href: "/admin/plugins/#{@props.plugin.name}/show"
            className: 'btn'
            onClick: @onToggleExpanded
          , 'more info'
