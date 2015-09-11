fs = require 'fs'
path = require 'path'
os = require 'os'

# Add support for obselete APIs of vm module so we can make some third-party
# modules work under node v0.11.x.
require 'vm-compatibility-layer'

_ = require 'underscore-plus'

packageJson = require '../package.json'

module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadNpmTasks('grunt-download-electron')
  grunt.loadNpmTasks('grunt-atom-shell-installer')
  grunt.loadNpmTasks('grunt-peg')
  grunt.loadTasks('tasks')

  # This allows all subsequent paths to the relative to the root of the repo
  grunt.file.setBase(path.resolve('..'))

  if not grunt.option('verbose')
    grunt.log.writeln = (args...) -> grunt.log
    grunt.log.write = (args...) -> grunt.log

  [major, minor, patch] = packageJson.version.split('.')
  tmpDir = os.tmpdir()

  pkgName = packageJson.name
  productName = packageJson.productName
  appName = if process.platform is 'darwin' then "#{productName}.app" else productName
  executableName = if process.platform is 'win32' then "#{productName}.exe" else productName
  executableName = executableName.toLowerCase() if process.platform is 'linux'

  buildDir = grunt.option('build-dir') ? path.resolve(__dirname, '..', 'dist/')
  buildDir = path.resolve(buildDir)
  installDir = grunt.option('install-dir')

  home = if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME
  atomShellDownloadDir = path.join(home, ".#{pkgName}", 'atom-shell')

  symbolsDir = path.join(buildDir, "#{productName}.breakpad.syms")
  shellAppDir = path.join(buildDir, appName)
  if process.platform is 'win32'
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= path.join(process.env.ProgramFiles, appName)
    killCommand = "taskkill /F /IM #{executableName}"
  else if process.platform is 'darwin'
    contentsDir = path.join(shellAppDir, 'Contents')
    appDir = path.join(contentsDir, 'Resources', 'app')
    installDir ?= path.join('/Applications', appName)
    killCommand = "pkill -9 #{executableName}"
  else
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= process.env.INSTALL_PREFIX ? '/usr/local'
    killCommand = "pkill -9 #{executableName}"

  installDir = path.resolve(installDir)

  coffeeConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.coffee'
        'spec/*.coffee'
        '!spec/*-spec.coffee'
        'exports/**/*.coffee'
        'static/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  lessConfig =
    options:
      paths: [
        'static/variables'
        'static'
      ]
    glob_to_multiple:
      expand: true
      src: [
        'static/**/*.less'
      ]
      dest: appDir
      ext: '.css'

  prebuildLessConfig =
    src: [
      'static/**/*.less'
      'node_modules/atom-space-pen-views/stylesheets/**/*.less'
    ]

  csonConfig =
    options:
      rootObject: true
      cachePath: path.join(home, ".#{pkgName}", 'compile-cache', 'grunt-cson')

    glob_to_multiple:
      expand: true
      src: [
        'menus/*.cson'
        'keymaps/*.cson'
        'static/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  pegConfig =
    glob_to_multiple:
      expand: true
      src: ['src/**/*.pegjs']
      dest: appDir
      ext: '.js'

  for child in fs.readdirSync('node_modules') when child isnt '.bin'
    directory = path.join('node_modules', child)
    metadataPath = path.join(directory, 'package.json')
    continue unless grunt.file.isFile(metadataPath)

    {engines, theme} = grunt.file.readJSON(metadataPath)
    if engines?.atom?
      coffeeConfig.glob_to_multiple.src.push("#{directory}/**/*.coffee")
      coffeeConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.coffee")

      lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
      lessConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.less")

      unless theme
        prebuildLessConfig.src.push("#{directory}/**/*.less")
        prebuildLessConfig.src.push("!#{directory}/spec/**/*.less")

      csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")
      csonConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.cson")

      pegConfig.glob_to_multiple.src.push("#{directory}/lib/*.pegjs")

  opts =
    name: pkgName
    pkg: grunt.file.readJSON('package.json')

    docsOutputDir: 'docs/output'

    coffee: coffeeConfig

    less: lessConfig

    'prebuild-less': prebuildLessConfig

    cson: csonConfig

    peg: pegConfig

    coffeelint:
      options:
        configFile: 'coffeelint.json'
      src: [
        'dot-atom/**/*.coffee'
        'exports/**/*.coffee'
        'src/**/*.coffee'
      ]
      build: [
        'build/tasks/**/*.coffee'
        'build/Gruntfile.coffee'
      ]
      test: [
        'spec/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
        'duplicate-background-images': false
        'box-model': false
        'box-sizing': false
        'bulletproof-font-face': false
        'compatible-vendor-prefixes': false
        'display-property-grouping': false
        'fallback-colors': false
        'font-sizes': false
        'gradients': false
        'ids': false
        'important': false
        'known-properties': false
        'outline-none': false
        'overqualified-elements': false
        'qualified-headings': false
        'unique-headings': false
        'universal-selector': false
        'vendor-prefix': false
      src: [
        'static/**/*.css'
      ]

    lesslint:
      src: [
        'static/**/*.less'
      ]

    'download-electron':
      version: packageJson.atomShellVersion
      outputDir: 'atom-shell'
      downloadDir: atomShellDownloadDir
      rebuild: true  # rebuild native modules after atom-shell is updated
      token: process.env.ATOM_ACCESS_TOKEN

    'create-windows-installer':
      appDirectory: shellAppDir
      outputDirectory: path.join(buildDir, 'installer')
      authors: packageJson.author
      loadingGif: path.resolve(__dirname, '..', 'resources', 'win', 'loading.gif')
      iconUrl: packageJson.iconUrl ? 'https://raw.githubusercontent.com/atom/atom/master/resources/win/atom.ico'
      setupIcon: path.resolve(__dirname, '..', 'resources', 'win', 'atom.ico')
      remoteReleases: 'https://atom.io/api/updates'

    mkdeb:
      section: 'misc'
      categories: 'GNOME;GTK;Development;Documentation'
      genericName: 'Demo Application'

    mkrpm:
      categories: 'GNOME;GTK;Development;Documentation'
      genericName: 'Demo Application'

    shell:
      'kill-app':
        command: killCommand
        options:
          stdout: false
          stderr: false
          failOnError: false

  opts[pkgName] = {appDir, appName, symbolsDir, buildDir, contentsDir, installDir, shellAppDir, productName, executableName}

  grunt.initConfig(opts)

  grunt.registerTask('compile', ['coffee', 'prebuild-less', 'cson', 'peg'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('test', ['shell:kill-app', 'run-specs'])

  ciTasks = ['output-disk-space', 'download-electron', 'download-electron-chromedriver', 'copy-rebrand-electron', 'build']
  ciTasks.push('dump-symbols') if process.platform isnt 'win32'
  ciTasks.push('set-version', 'check-licenses', 'lint', 'generate-asar')
  ciTasks.push('mkdeb') if process.platform is 'linux'
  ciTasks.push('create-windows-installer') if process.platform is 'win32'
  ciTasks.push('test') if process.platform is 'darwin'
  ciTasks.push('codesign') unless process.env.TRAVIS
  ciTasks.push('publish-build') unless process.env.TRAVIS
  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-electron', 'download-electron-chromedriver', 'copy-rebrand-electron', 'build', 'set-version', 'generate-asar']
  defaultTasks.push 'install' unless process.platform is 'linux'
  grunt.registerTask('default', defaultTasks)
