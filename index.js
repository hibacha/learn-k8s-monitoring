//Lets require/import the HTTP module
const http = require('http');
const os = require('os');
const sleep = require('system-sleep');
const express = require('express');
const throng = require('throng');

var startWorker = function() {
  var app = express()

  var spin = function(count) {
    var start = new Date();
    var i = 0;
    while(i < count) {
       i++;
    }
  }

  var nextNumber = function(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  app.get('/', function (req, res) {
    // Root isn't allowed in OpenAPI
    res.status(404).send()
  })

  app.get('/healthz', function(req, res) {
    res.send('Ok')
  })

  app.get('/doFail', function(req, res) {
    res.status(500).send('Internal Server Error')
  })

  app.get('/doWork', function(req, res) {
    var deserializeWork = nextNumber(300000, 500000);
    var downstreamDelay = nextNumber(100, 200);
    var serializeWork = nextNumber(300000, 500000);

    spin(deserializeWork);
    sleep(downstreamDelay);
    spin(serializeWork);

    res.send(
      'Ended after:' +
      ' deserializeWork: ' + deserializeWork +
      ', downstreamDelay: ' + downstreamDelay +
      ', serializeWork: ' + serializeWork
    )
  })

  app.listen(8080, function () {
    console.log('listening on port 8080...')
  })
}

throng({
  workers: 4, // Number of workers (cpu count)
  start: startWorker // Function to call when starting the worker processes
});
