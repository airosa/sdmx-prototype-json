# live-test-client-ts

Experimental SDMX RESTful web service client for testing and development. Written in CoffeeScript, runs in a web browser. 

## Features

- Supports SDMX 2.1 RESTful web API (only for data queries)
- Requests and consumes responses in experimental JSON format
- Should work with any WS and Data flow
- Supports optional custom query parameters 

## Benefits

- Supports explorative testing of the RESTful web service and experimental JSON format
- Demonstrates time series oriented visualisation with working code

## Installation

1. Open the file app/index.html in a browser.

Index.html loads all dependencies automatically. Following libraries are used:

- [Twitter Bootstrap](http://twitter.github.com/bootstrap/index.html) framework
for the basic web application features (HTML, CSS etc.)
- [AngularJS](http://angularjs.org) JavaScript MVW framework for the GUI.
- [D3.js](http://d3js.org) JavaScript library for the time series charts. 

## Usage

1. Update the Web Service parameters. Defaults to a test WS. Click "Get Dimensions".
2. Select dimension values (click Show/Hide to display dimension codes). By default
first code value is selected for all dimensions. If nothing is selected then all
available codes are requested. Click "Get Data".
3. Results are displayed as time series charts. Click "Show/Hide" to display series
level attributes.

For more information about the SDMX RESTful web API see the SDMX standard section 7 "Guidelines for the Use of Web Services". 





