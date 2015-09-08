# {$, $$} = require '../src/space-pen-extensions'
path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
TextEditor = require '../src/text-editor'
WindowEventHandler = require '../src/window-event-handler'
View = require 'space-view'

describe "Window", ->
  [projectPath, windowEventHandler] = []

  beforeEach ->
    spyOn(atom, 'hide')
    initialPath = atom.project.getPaths()[0]
    spyOn(atom, 'getLoadSettings').andCallFake ->
      loadSettings = atom.getLoadSettings.originalValue.call(atom)
      loadSettings.initialPath = initialPath
      loadSettings
    atom.project.destroy()
    windowEventHandler = new WindowEventHandler()
    atom.deserializeEditorWindow()
    projectPath = atom.project.getPaths()[0]

  afterEach ->
    windowEventHandler.unsubscribe()

  describe "when the window is loaded", ->
    it "doesn't have .is-blurred on the body tag", ->
      expect(document.body).not.toHaveClass("is-blurred")

  describe "when the window is blurred", ->
    beforeEach ->
      window.dispatchEvent new FocusEvent('blur')

    afterEach ->
      document.body.classList.remove('is-blurred')

    it "adds the .is-blurred class on the body", ->
      expect(document.body).toHaveClass("is-blurred")

    describe "when the window is focused again", ->
      it "removes the .is-blurred class from the body", ->
        window.dispatchEvent new FocusEvent('focus')
        expect(document.body).not.toHaveClass("is-blurred")

  describe "window:close event", ->
    it "closes the window", ->
      spyOn(atom, 'close')
      atom.commands.dispatch window, 'window:close'
      expect(atom.close).toHaveBeenCalled()

  describe "beforeunload event", ->
    [beforeUnloadEvent] = []

    beforeEach ->
      jasmine.unspy(TextEditor.prototype, "shouldPromptToSave")
      beforeUnloadEvent = new Event('beforeunload')

    describe "when pane items are modified", ->
      it "prompts user to save and calls atom.workspace.confirmClose", ->
        editor = null
        spyOn(atom.workspace, 'confirmClose').andCallThrough()
        spyOn(atom, "confirm").andReturn(2)

        waitsForPromise ->
          atom.workspace.open("sample.js").then (o) -> editor = o

        runs ->
          editor.insertText("I look different, I feel different.")
          window.dispatchEvent beforeUnloadEvent
          expect(atom.workspace.confirmClose).toHaveBeenCalled()
          expect(atom.confirm).toHaveBeenCalled()

      it "prompts user to save and handler returns true if don't save", ->
        editor = null
        spyOn(atom, "confirm").andReturn(2)

        waitsForPromise ->
          atom.workspace.open("sample.js").then (o) -> editor = o

        runs ->
          editor.insertText("I look different, I feel different.")
          window.dispatchEvent beforeUnloadEvent
          expect(atom.confirm).toHaveBeenCalled()

      it "prompts user to save and handler returns false if dialog is canceled", ->
        editor = null
        spyOn(atom, "confirm").andReturn(1)
        waitsForPromise ->
          atom.workspace.open("sample.js").then (o) -> editor = o

        runs ->
          editor.insertText("I look different, I feel different.")
          window.dispatchEvent beforeUnloadEvent
          expect(atom.confirm).toHaveBeenCalled()

      describe "when the same path is modified in multiple panes", ->
        it "prompts to save the item", ->
          editor = null
          filePath = path.join(temp.mkdirSync('atom-file'), 'file.txt')
          fs.writeFileSync(filePath, 'hello')
          spyOn(atom.workspace, 'confirmClose').andCallThrough()
          spyOn(atom, 'confirm').andReturn(0)

          waitsForPromise ->
            atom.workspace.open(filePath).then (o) -> editor = o

          runs ->
            atom.workspace.getActivePane().splitRight(copyActiveItem: true)
            editor.setText('world')
            window.dispatchEvent beforeUnloadEvent
            expect(atom.workspace.confirmClose).toHaveBeenCalled()
            expect(atom.confirm.callCount).toBe 1
            expect(fs.readFileSync(filePath, 'utf8')).toBe 'world'

  describe ".unloadEditorWindow()", ->
    it "saves the serialized state of the window so it can be deserialized after reload", ->
      workspaceState = atom.workspace.serialize()
      syntaxState = atom.grammars.serialize()
      projectState = atom.project.serialize()

      atom.unloadEditorWindow()

      expect(atom.state.workspace).toEqual workspaceState
      expect(atom.state.grammars).toEqual syntaxState
      expect(atom.state.project).toEqual projectState
      expect(atom.saveSync).toHaveBeenCalled()

  describe ".removeEditorWindow()", ->
    it "unsubscribes from all buffers", ->
      waitsForPromise ->
        atom.workspace.open("sample.js")

      runs ->
        buffer = atom.workspace.getActivePaneItem().buffer
        pane = atom.workspace.getActivePane()
        pane.splitRight(copyActiveItem: true)
        expect(atom.workspace.getTextEditors().length).toBe 2

        atom.removeEditorWindow()

        # expect(buffer.getSubscriptionCount()).toBe 0

  describe "when a link is clicked", ->
    it "opens the http/https links in an external application", ->
      shell = require 'shell'
      spyOn(shell, 'openExternal')

      clickRemoveLink = (href)->
        linkNode = View.buildDOMFromHTML("<a href='#{href}'>the website</a>")
        document.body.appendChild linkNode
        linkNode.dispatchEvent new Event('click', {bubbles: true, cancelable: true})
        linkNode.remove()

      clickRemoveLink('http://github.com')
      expect(shell.openExternal).toHaveBeenCalled()
      expect(shell.openExternal.argsForCall[0][0]).toBe "http://github.com"

      shell.openExternal.reset()
      clickRemoveLink('https://github.com')
      expect(shell.openExternal).toHaveBeenCalled()
      expect(shell.openExternal.argsForCall[0][0]).toBe "https://github.com"

      shell.openExternal.reset()
      clickRemoveLink('')
      expect(shell.openExternal).not.toHaveBeenCalled()

      shell.openExternal.reset()
      clickRemoveLink('#scroll-me')
      expect(shell.openExternal).not.toHaveBeenCalled()

  describe "when a form is submitted", ->
    it "prevents the default so that the window's URL isn't changed", ->
      submitSpy = jasmine.createSpy('submit')
      windowEventHandler.subscribeEvent document, 'submit', submitSpy
      formNode = View.buildDOMFromHTML("<form>foo</form>")
      document.body.appendChild(formNode)
      formNode.dispatchEvent new Event('submit', {bubbles: true, cancelable: true})
      formNode.remove()
      expect(submitSpy.callCount).toBe 1
      expect(submitSpy.argsForCall[0][0].defaultPrevented).toBe true

  describe "core:focus-next and core:focus-previous", ->
    describe "when there is no currently focused element", ->
      it "focuses the element with the lowest/highest tabindex", ->
        elements = View.render ->
          @div =>
            @button tabindex: 2
            @input tabindex: 1

        jasmine.attachToDOM(elements)

        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector('[tabindex="1"]:focus')).toBeTruthy()

        document.querySelector(":focus").blur()

        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector('[tabindex="2"]:focus')).toBeTruthy()

    describe "when a tabindex is set on the currently focused element", ->
      it "focuses the element with the next highest tabindex", ->
        elements = View.render ->
          @div =>
            @input tabindex: 1
            @button tabindex: 2
            @button tabindex: 5
            @input tabindex: -1
            @input tabindex: 3
            @button tabindex: 7

        jasmine.attachToDOM(elements)
        elements.querySelector("[tabindex=\"1\"]").focus()

        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"2\"]:focus")).toBeTruthy()

        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"3\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"5\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"7\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"1\"]:focus")).toBeTruthy()

        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"7\"]:focus")).toBeTruthy()

        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"5\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"3\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"2\"]:focus")).toBeTruthy()

        elements.focus()
        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"1\"]:focus")).toBeTruthy()

      it "skips disabled elements", ->
        elements = View.render ->
          @div =>
            @input tabindex: 1
            @button tabindex: 2, disabled: 'disabled'
            @input tabindex: 3

        jasmine.attachToDOM(elements)
        elements.querySelector("[tabindex=\"1\"]").focus()

        atom.commands.dispatch elements, "core:focus-next"
        expect(elements.querySelector("[tabindex=\"3\"]:focus")).toBeTruthy()

        atom.commands.dispatch elements, "core:focus-previous"
        expect(elements.querySelector("[tabindex=\"1\"]:focus")).toBeTruthy()

  describe "the window:open-locations event", ->
    beforeEach ->
      spyOn(atom.workspace, 'open')
      atom.project.setPaths([])

    describe "when the opened path exists", ->
      it "adds it to the project's paths", ->
        pathToOpen = __filename
        atom.getCurrentWindow().send 'message', 'open-locations', [{pathToOpen}]

        waitsFor ->
          atom.project.getPaths().length is 1

        runs ->
          expect(atom.project.getPaths()[0]).toBe __dirname

    describe "when the opened path does not exist but its parent directory does", ->
      it "adds the parent directory to the project paths", ->
        pathToOpen = path.join(__dirname, 'this-path-does-not-exist.txt')
        atom.getCurrentWindow().send 'message', 'open-locations', [{pathToOpen}]

        waitsFor ->
          atom.project.getPaths().length is 1

        runs ->
          expect(atom.project.getPaths()[0]).toBe __dirname

    describe "when the opened path is a file", ->
      it "opens it in the workspace", ->
        pathToOpen = __filename
        atom.getCurrentWindow().send 'message', 'open-locations', [{pathToOpen}]

        waitsFor ->
          atom.workspace.open.callCount is 1

        runs ->
          expect(atom.workspace.open.mostRecentCall.args[0]).toBe __filename


    describe "when the opened path is a directory", ->
      it "does not open it in the workspace", ->
        pathToOpen = __dirname
        atom.getCurrentWindow().send 'message', 'open-locations', [{pathToOpen}]
        expect(atom.workspace.open.callCount).toBe 0

    describe "when the opened path is a uri", ->
      it "adds it to the project's paths as is", ->
        pathToOpen = 'remote://server:7644/some/dir/path'
        atom.getCurrentWindow().send 'message', 'open-locations', [{pathToOpen}]

        waitsFor ->
          atom.project.getPaths().length is 1

        runs ->
          expect(atom.project.getPaths()[0]).toBe pathToOpen
