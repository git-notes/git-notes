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

    outDir = path.resolve(__dirname, 'out')
    fs.mkdirSync(outDir) unless fs.existsSync(outDir)
    logFile = global.loadSettings.logFile ? path.resolve(outDir, 'log.txt')
    logStream = fs.openSync(logFile, 'w') if logFile?
    log = (str) -> fs.writeSync(logStream, str)

    ConsoleReporter = require './reporter/console-reporter'
    reporter = new jasmine.ConsoleReporter
      print: (str) ->
        log(str)
      onComplete: (allPassed) ->
        fs.closeSync(logStream) if logStream?
        app.exit(if allPassed then 0 else 1)

    jasmineEnv = jasmine.getEnv()
    jasmineEnv.addReporter(reporter)

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
