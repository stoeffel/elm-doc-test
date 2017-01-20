// imports
var path = require('path');
var mkdirp = require("mkdirp");
var fs = require("fs");
var Elm = require("./elm.js");
var helpers = require('./cli-helpers.js');



/* Running modes currently supported are either
   - generate, to generate tests as part of your suite
   - run, to run a single file, provide the file name
*/
var RUNNING_MODE = {
  GENERATE: 0,
  RUN: 1
};

// runners are called via `.run` on a model
var running_mode_runners = {};
running_mode_runners[RUNNING_MODE.GENERATE] = generate;
running_mode_runners[RUNNING_MODE.RUN] = run;


// loaders are called by init
var running_mode_loaders = {};

running_mode_loaders[RUNNING_MODE.GENERATE] = function(options){

  return {
    runningMode: RUNNING_MODE.GENERATE,
    getConfig: helpers.loadDocTestConfig,
    run: running_mode_runners[RUNNING_MODE.GENERATE],
    showWarnings: options.showWarnings,
    output: options.output
  };
};

running_mode_loaders[RUNNING_MODE.RUN] = function(argv, options){
  var files = argv.run;

  var getConfig = function (cb) {
    cb({ files: files });
  };

  return {
    runningMode: RUNNING_MODE.RUN,
    getConfig: getConfig,
    run: running_mode_runners[RUNNING_MODE.RUN],
    showWarnings: options.showWarnings,
    output: options.output
  };
};


// parse args
function init(argv){
  var model = null;

  var options = {
    showWarnings: true,
    output: "tests"
  };

  if (typeof argv.warn !== "undefined") {
    options.showWarnings = argv.warn;
  }

  if (typeof argv.output !== "undefined") {
    options.output = argv.output;
  }

  if (typeof argv.run === "undefined") {
    if (options.showWarnings) console.log('Running in generate mode..');
    model = running_mode_loaders[RUNNING_MODE.GENERATE](options);
  } else {
    if (options.showWarnings) console.log('Running in run mode..');
    model = running_mode_loaders[RUNNING_MODE.RUN](argv, options);
  }

  return model;
}

function run(model){
  model.getConfig(function(config) {
    var files = config.files.split(' ');
    files = files.filter(
      function(v){ return v.endsWith('.elm'); }
    ).map(elmPathToModule);

    console.log(files);
  });
}

function generate(model, allTestsGenerated) {
  model.getConfig(function(config) {
    var testsDocPath = path.join(model.output, "Doc");

    helpers.createDocTest(testsDocPath, config, function() {
      var app = Elm.DocTest.worker(config);

      app.ports.readFile.subscribe(function(test) {
        fs.readFile(
            test[1],
            "utf8",
            function(err, data) {
          if (err) {
            console.error(err);
            process.exit(-1);
            return;
          }
          app.ports.generateModuleDoctest.send([test[0], data]);
        });
      });

      var writtenTests = 0;
      app.ports.writeFile.subscribe(function(data) {
        var test = data[1];
        var parts = data[0].split(".");
        var modulePath = [];
        var moduleName = ".";

        if (parts.length > 1) {
          modulePath = parts.slice(0, -1);
          moduleName = parts.slice(-1)[0];
        } else {
          moduleName = parts[0];
        }

        var testsDocModulePath = path.join(
          testsDocPath,
          modulePath.join("/")
        );

        mkdirp(testsDocModulePath, function(err) {
          if (err) {
            console.error(err);
            process.exit(-1);
            return;
          }
          fs.writeFile(
            path.join(testsDocModulePath, moduleName + "Spec.elm"),
            test,
            "utf8",
            function(err) {
              if (err) {
                console.error(err);
                process.exit(-1);
                return;
              }

              writtenTests = writtenTests + 1;
              if (writtenTests === config.length && allTestsGenerated) {
                allTestsGenerated();
              }
          });
        });
      });
    });
  });
}

function elmPathToModule(pathName){
  return pathName.substr(0, pathName.length - 4).replace("/", ".");
}

function elmModuleToPath(moduleName){
  return moduleName.replace(/\./g, "/") + ".elm";
}

module.exports = {
  RUNNING_MODE: RUNNING_MODE,
  init: init
};
