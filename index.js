//Lets require/import the HTTP module
const http = require('http');
const os = require('os');
const sleep = require('system-sleep');
const express = require('express');
const throng = require('throng');

// fake some startup time.
sleep(3000);

var startWorker = function() {
  var app = express()

  var spin = function(timeInMs) {
    var start = new Date();
    var i = 0;
    while(new Date().getTime() < start.getTime() + timeInMs) { // SYNC!
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
    var deserializeDelay = nextNumber(10, 100);
    var downstreamDelay = nextNumber(100, 200);
    var serializeDelay = nextNumber(10, 100);

    spin(deserializeDelay);

    if(downstreamDelay >= 199) {
      // LUUUCKY.
      sleep(60 * 1000);
    } else {
      sleep(downstreamDelay);
    }

    spin(serializeDelay);

    res.send(
      'Ended after:' +
      ' deserializeDelay: ' + deserializeDelay +
      ', downstreamDelay: ' + downstreamDelay +
      ', serializeDelay: ' + serializeDelay
    )
  })

  app.listen(8080, function () {
    console.log('listening on port 8080...')
  })
}

throng({
  workers: 5,       // Number of workers (cpu count)
  start: startWorker    // Function to call when starting the worker processes
});
