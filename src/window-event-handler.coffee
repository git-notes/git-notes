path = require 'path'
ipc = require 'ipc'
shell = require 'shell'
fs = require 'fs-plus'
{CompositeDisposable, Disposable} = require 'event-kit'

# Handles low-level events related to the window.
module.exports =
class WindowEventHandler

  constructor: ->
    @reloadRequested = false
    @subscriptions = new CompositeDisposable

    @subscribeIpc 'message', (message, detail) ->
      switch message
        when 'open-locations'
          needsProjectPaths = atom.project?.getPaths().length is 0

          for {pathToOpen, initialLine, initialColumn} in detail
            if pathToOpen? and needsProjectPaths
              if fs.existsSync(pathToOpen)
                atom.project.addPath(pathToOpen)
              else if fs.existsSync(path.dirname(pathToOpen))
                atom.project.addPath(path.dirname(pathToOpen))
              else
                atom.project.addPath(pathToOpen)

            unless fs.isDirectorySync(pathToOpen)
              atom.workspace?.open(pathToOpen, {initialLine, initialColumn})

          return

        when 'update-available'
          atom.updateAvailable(detail)

          # FIXME: Remove this when deprecations are removed
          {releaseVersion} = detail
          detail = [releaseVersion]
          if workspaceElement = atom.views.getView(atom.workspace)
            atom.commands.dispatch workspaceElement, "window:update-available", detail

    @subscribeIpc 'command', (command, args...) ->
      activeElement = document.activeElement
      # Use the workspace element view if body has focus
      if activeElement is document.body and workspaceElement = atom.views.getView(atom.workspace)
        activeElement = workspaceElement

      atom.commands.dispatch(activeElement, command, args[0])

    @subscribeIpc 'context-command', (command, args...) ->
      $(atom.contextMenu.activeElement).trigger(command, args...)

    @subscribeEvent window, 'focus', -> document.body.classList.remove('is-blurred')

    @subscribeEvent window, 'blur', ->
      document.body.classList.add('is-blurred')
      atom.storeDefaultWindowDimensions()

    @subscribeEvent window, 'beforeunload', =>
      confirmed = atom.workspace?.confirmClose(windowCloseRequested: true)
      atom.hide() if confirmed and not @reloadRequested and atom.getCurrentWindow().isWebViewFocused()
      @reloadRequested = false

      atom.storeDefaultWindowDimensions()
      atom.storeWindowDimensions()
      if confirmed
        atom.unloadEditorWindow()
      else
        ipc.send('cancel-window-close')

      confirmed

    @subscribeEvent window, 'unload', -> atom.removeEditorWindow()

    @subscriptions.add atom.commands.add window,
      'window:toggle-full-screen': -> atom.toggleFullScreen()
      'window:close': -> atom.close()
      'window:reload': =>
        @reloadRequested = true
        atom.reload()
      'window:toggle-dev-tools': -> atom.toggleDevTools()

    if process.platform in ['win32', 'linux']
      @subscriptions.add atom.commands.add window, 'window:toggle-menu-bar', ->
        atom.config.set('core.autoHideMenuBar', not atom.config.get('core.autoHideMenuBar'))

    @subscriptions.add atom.commands.add document,
      'core:focus-next', @focusNext
      'core:focus-previous', @focusPrevious

    @subscribeEvent document, 'keydown', @onKeydown

    @subscribeEvent document, 'drop', @onDrop

    @subscribeEvent document, 'dragover', @onDragOver

    @subscribeEvent document, 'click', (event) =>
       @openLink() if event.target.matches('a')

    # Prevent form submits from changing the current window's URL
    @subscribeEvent document, 'submit', (event) ->
      event.preventDefault() if event.target.matches('form')

    @subscribeEvent document, 'contextmenu', (event) ->
      event.preventDefault()
      atom.contextMenu.showForEvent(event)

    @handleNativeKeybindings()

  subscribeIpc: (name, callback) ->
    ipc.on name, callback
    @subscriptions.add new Disposable -> ipc.removeListener name, callback

  subscribeEvent: (element, event, callback) ->
    element.addEventListener event, callback
    @subscriptions.add new Disposable -> element.removeEventListener event, callback

  unsubscribe: ->
    @subscriptions.dispose()

  # Wire commands that should be handled by Chromium for elements with the
  # `.native-key-bindings` class.
  handleNativeKeybindings: ->
    menu = null
    bindCommandToAction = (command, action) =>
      @subscribeEvent document, command, (event) ->
        if event.target.webkitMatchesSelector('.native-key-bindings')
          atom.getCurrentWindow().webContents[action]()
        true

    bindCommandToAction('core:copy', 'copy')
    bindCommandToAction('core:paste', 'paste')
    bindCommandToAction('core:undo', 'undo')
    bindCommandToAction('core:redo', 'redo')
    bindCommandToAction('core:select-all', 'selectAll')
    bindCommandToAction('core:cut', 'cut')

  onKeydown: (event) ->
    atom.keymaps.handleKeyboardEvent(event)
    event.stopImmediatePropagation()

  onDrop: (event) ->
    event.preventDefault()
    event.stopPropagation()

  onDragOver: (event) ->
    event.preventDefault()
    event.stopPropagation()
    event.dataTransfer.dropEffect = 'none'

  openLink: ({target, currentTarget}) ->
    location = target?.getAttribute('href') or currentTarget?.getAttribute('href')
    if location and location[0] isnt '#' and /^https?:\/\//.test(location)
      shell.openExternal(location)
    false

  eachTabIndexedElement: (callback) ->
    for element in document.querySelectorAll('[tabindex]')
      continue if element.disabled

      tabIndex = element.tabIndex
      continue unless tabIndex >= 0

      callback(element, tabIndex)
    return

  getFocusedTabIndex = ->
    document.querySelector(':focus')?.tabIndex or -Infinity

  focusNext: =>
    focusedTabIndex = getFocusedTabIndex()

    nextElement = null
    nextTabIndex = Infinity
    lowestElement = null
    lowestTabIndex = Infinity
    @eachTabIndexedElement (element, tabIndex) ->
      if tabIndex < lowestTabIndex
        lowestTabIndex = tabIndex
        lowestElement = element

      if focusedTabIndex < tabIndex < nextTabIndex
        nextTabIndex = tabIndex
        nextElement = element

    if nextElement?
      nextElement.focus()
    else if lowestElement?
      lowestElement.focus()

  focusPrevious: =>
    focusedTabIndex = getFocusedTabIndex()

    previousElement = null
    previousTabIndex = -Infinity
    highestElement = null
    highestTabIndex = -Infinity
    @eachTabIndexedElement (element, tabIndex) ->
      if tabIndex > highestTabIndex
        highestTabIndex = tabIndex
        highestElement = element

      if focusedTabIndex > tabIndex > previousTabIndex
        previousTabIndex = tabIndex
        previousElement = element

    if previousElement?
      previousElement.focus()
    else if highestElement?
      highestElement.focus()
