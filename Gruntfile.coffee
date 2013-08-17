module.exports = (grunt) ->
  grunt.initConfig(
    pkg: grunt.file.readJSON('package.json')

    uglify:
      options:
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
      build:
        files:
          "scripts/build/hungry.min.js": [
           "scripts/build/hungry.js"
          ]

    coffee:
      compile:
        files:
          "scripts/build/hungry.js": [
            "scripts/hungry.coffee"
          ]

    concat:
      application:
        files:
          "scripts/build/lib.js": [
            "scripts/lib/underscore-min.js",
            "scripts/lib/backbone-min.js"
            "scripts/lib/backbone.marionette.min.js",
          ]

          "application.min.js": [
            "scripts/build/lib.js"
            "scripts/build/hungry.min.js"
          ]
        
  )  # End config

  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-concat')

  grunt.registerTask('default', ['coffee', 'uglify', 'concat'])
