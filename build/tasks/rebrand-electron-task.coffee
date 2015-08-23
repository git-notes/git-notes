path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs'

module.exports = (grunt) ->

  rename = (basePath, oldName, newName) ->
    fs.renameSync(path.join(basePath, oldName), path.join(basePath, newName))

  moveHelpers = (frameworksPath, appName) ->
    for suffix in [' Helper', ' Helper EH', ' Helper NP']
      executableBasePath = path.join(frameworksPath, 'Electron' + suffix + '.app', 'Contents', 'MacOS')
      rename executableBasePath, 'Electron' + suffix, appName + suffix
      rename frameworksPath, 'Electron' + suffix + '.app', appName + suffix + '.app'

  grunt.registerTask 'rebrand-electron', 'Rebrand Electron', ->
    pkgName = grunt.config.get('name')

    shellAppDir = grunt.config.get("#{pkgName}.shellAppDir")
    appName = grunt.config.get("#{pkgName}.appName")
    productName = grunt.config.get("#{pkgName}.productName")

    switch process.platform
      when 'win32'
        oldName = path.resolve(shellAppDir, 'electron.exe')
        newName = path.resolve(shellAppDir, "#{appName}.exe")
        fs.renameSync oldName, newName
      when 'linux'
        oldName = path.resolve(shellAppDir, 'electron')
        newName = path.resolve(shellAppDir, appName)
        fs.renameSync oldName, newName
      when 'darwin'
        contentsPath = grunt.config.get("#{pkgName}.contentsDir")
        defaultBundleName = 'com.electron.' + pkgName

        frameworksPath = path.join(contentsPath, 'Frameworks')
        helperPlistFilename = path.join(frameworksPath, 'Electron Helper.app', 'Contents', 'Info.plist')
        appPlistFilename = path.join(contentsPath, 'Info.plist')

        plist = require('plist')
        appPlist = plist.parse(fs.readFileSync(appPlistFilename).toString())
        helperPlist = plist.parse(fs.readFileSync(helperPlistFilename).toString())

        appPlist.CFBundleExecutable = productName
        appPlist.CFBundleDisplayName = pkgName
        appPlist.CFBundleIdentifier = grunt.config.get("#{@name}.app-bundle-id") or defaultBundleName
        appPlist.CFBundleName = pkgName
        helperPlist.CFBundleIdentifier = grunt.config.get("#{@name}.helper-bundle-id") or defaultBundleName + '.helper'
        helperPlist.CFBundleName = pkgName

        appVersion = grunt.config.get("#{@name}.appVersion")
        appPlist.CFBundleVersion = appVersion if appVersion

        protocols = grunt.config.get("#{@name}.protocols")
        if protocols
          helperPlist.CFBundleURLTypes = appPlist.CFBundleURLTypes = protocols.map (protocol) ->
            CFBundleURLName: protocol.name,
            CFBundleURLSchemes: [].concat(protocol.schemes)

        fs.writeFileSync(appPlistFilename, plist.build(appPlist))
        fs.writeFileSync(helperPlistFilename, plist.build(helperPlist))
        moveHelpers frameworksPath, productName
        executableBasePath = path.join(contentsPath, 'MacOS')
        rename executableBasePath, 'Electron', productName

  grunt.registerTask 'copy-rebrand-electron', 'Copy and Rebrand Electron', ->
    {cp, mkdir, rm} = require('./task-helpers')(grunt)

    pkgName = grunt.config.get('name')
    shellAppDir = grunt.config.get("#{pkgName}.shellAppDir")
    buildDir = grunt.config.get("#{pkgName}.buildDir")

    rm shellAppDir
    mkdir path.dirname(buildDir)

    switch process.platform
      when 'darwin'
        cp "atom-shell/Electron.app", shellAppDir, filter: /default_app/
      when 'linux', 'win32'
        cp 'atom-shell', shellAppDir, filter: /default_app/
    grunt.task.run 'rebrand-electron'
