fs = require 'fs-plus'
path = require 'path'
remote = require 'remote'
app = remote.require 'app'

@pkgJson = require 'package.json'

# Start the crash reporter before anything else.
require('crash-reporter').start(productName: @pkgJson.name, companyName: 'atom-shell-starter')
specRootPath = path.resolve(global.loadSettings.resourcePath, 'spec/')

runSpecSuite = (logFile) ->
  if global.loadSettings.exitWhenDone
    jasmineFn = require 'jasmine'
    jasmineFn(global.jasmine)

    logFile = global.loadSettings.logFile ? path.resolve(__dirname, 'log.txt')
    logStream = fs.openSync(logFile, 'w') if logFile?
    log = (str) ->
      if logStream?
        fs.writeSync(logStream, str)
      else
        process.stderr.write(str)
    {TerminalReporter} = require 'jasmine-tagged'

    reporter = new TerminalReporter
      print: (str) ->
        log(str)
      onComplete: (runner) ->
        fs.closeSync(logStream) if logStream?
        if runner.results().failedCount > 0 then atom.exit(1) else atom.exit(0)

    jasmineEnv = jasmine.getEnv()
    jasmineEnv.addReporter(reporter)
    # jasmineEnv.setIncludedTags([process.platform])

    for specFilePath in fs.listTreeSync(specRootPath) when /-spec\.(coffee|js)$/.test specFilePath
      require specFilePath
    jasmineEnv.execute()
  else
    link = document.createElement 'link'
    link.rel = 'stylesheet'
    link.href = '../vendor/jasmine/lib/jasmine-2.1.3/jasmine.css'
    document.head.appendChild link

    window.jasmineRequire = require '../vendor/jasmine/lib/jasmine-2.1.3/jasmine'
    require '../vendor/jasmine/lib/jasmine-2.1.3/jasmine-html'
    require '../vendor/jasmine/lib/jasmine-2.1.3/boot'

    for specFilePath in fs.listTreeSync(specRootPath) when /-spec\.(coffee|js)$/.test specFilePath
      require specFilePath

    window.jasmineExecute()

runSpecSuite()
