fs = require 'fs-plus'
path = require 'path'
remote = require 'remote'
app = remote.require 'app'

@pkgJson = require 'package.json'

# Start the crash reporter before anything else.
require('crash-reporter').start(productName: @pkgJson.name, companyName: 'atom-shell-starter')
specRootPath = path.resolve(global.loadSettings.resourcePath, 'spec/')

jasmineReport: ->
  link = document.createElement 'link'
  link.rel = 'stylesheet'
  link.href = '../vendor/jasmine/lib/jasmine-2.1.3/jasmine.css'
  document.head.appendChild link

  window.jasmineRequire = require '../vendor/jasmine/lib/jasmine-2.1.3/jasmine'
  require '../vendor/jasmine/lib/jasmine-2.1.3/jasmine-html'
  require '../vendor/jasmine/lib/jasmine-2.1.3/boot'

  window.jasmineExecute()

runSpecSuite = (logFile) ->
  jasmineFn = require 'jasmine'
  jasmineFn(global.jasmine)
  if false #global.loadSettings.exitWhenDone
    outDir = path.resolve(__dirname, 'out')
    fs.mkdirSync(outDir) unless fs.existsSync(outDir)
    logFile = global.loadSettings.logFile ? path.resolve(outDir, 'log.md')
    logStream = fs.openSync(logFile, 'w') if logFile?
    log = (str) -> fs.writeSync(logStream, str)

    MdReporter = require 'jasmine-md-reporter'
    reporter = new MdReporter
      basePath: path.resolve(__dirname, '..')
      ignoreStackPatterns: 'node_modules/jasmine/**'
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
    XmailReporter = require './xmail-reporter'
    reporter = new XmailReporter

    console.log jasmine
    jasmineEnv = jasmine.getEnv()
    jasmineEnv.addReporter(reporter)
    for specFilePath in fs.listTreeSync(specRootPath) when /-spec\.(coffee|js)$/.test specFilePath
      require specFilePath
    jasmineEnv.execute()

runSpecSuite()
