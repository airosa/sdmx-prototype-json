// Generated by CoffeeScript 1.3.3
(function() {
  var DATA_FILE, PORT_NUMBER, SERVER_NAME, SERVER_VERSION, addCodesToQuery, calculateIndexMultipliers, compressResponse, dataset, findDataFlow, fs, handleRequest, http, loadDataset, log, parse, parseDataQuery, parseDate, parseFlowRef, parseKey, parseProviderRef, parseQueryParams, query, timePeriodToDate, url, validateRequest, zlib;

  http = require('http');

  url = require('url');

  fs = require('fs');

  zlib = require('zlib');

  SERVER_NAME = 'LIVE-TEST-WS';

  SERVER_VERSION = '0.2.10';

  PORT_NUMBER = process.env.PORT || 8081;

  DATA_FILE = 'hicp-coicop-inx.json';

  dataset = null;

  log = function(msg) {
    return console.log("" + (new Date().toTimeString().slice(0, 8)) + " " + msg);
  };

  calculateIndexMultipliers = function(dimensions) {
    var dim, i, multipliers, prev, reversedDimensions, _i, _len;
    multipliers = new Array(dimensions.length);
    reversedDimensions = dimensions.slice().reverse();
    prev = 1;
    for (i = _i = 0, _len = reversedDimensions.length; _i < _len; i = ++_i) {
      dim = reversedDimensions[i];
      multipliers[i] = prev;
      prev = dim.length * prev;
    }
    return multipliers.reverse();
  };

  loadDataset = function(filename) {
    var data, jsonString;
    jsonString = fs.readFileSync(filename);
    data = JSON.parse(jsonString);
    return data;
  };

  exports.timePeriodToDate = timePeriodToDate = function(frequency, year, period, end) {
    var date;
    if (year % 1 !== 0) {
      return null;
    }
    if (period % 1 !== 0) {
      return null;
    }
    if (period < 1) {
      return null;
    }
    date = new Date(Date.UTC(year, 0, 1, 0, 0, 0));
    if (!end) {
      period = period - 1;
    }
    switch (frequency) {
      case 'A':
        if (1 < period) {
          return null;
        }
        date.setUTCMonth(date.getUTCMonth() + (12 * period));
        break;
      case 'S':
        if (2 < period) {
          return null;
        }
        date.setUTCMonth(date.getUTCMonth() + (6 * period));
        break;
      case 'T':
        if (3 < period) {
          return null;
        }
        date.setUTCMonth(date.getUTCMonth() + (4 * period));
        break;
      case 'Q':
        if (4 < period) {
          return null;
        }
        date.setUTCMonth(date.getUTCMonth() + (3 * period));
        break;
      case 'M':
        if (12 < period) {
          return null;
        }
        date.setUTCMonth(date.getUTCMonth() + period);
        break;
      case 'W':
        if (53 < period) {
          return null;
        }
        if (date.getUTCDay() !== 4) {
          date.setUTCMonth(0, 1 + (((4 - date.getUTCDay()) + 7) % 7));
        }
        date.setUTCDate(date.getUTCDate() - 3);
        date.setUTCDate(date.getUTCDate() + (7 * period));
        break;
      case 'D':
        if (366 < period) {
          return null;
        }
        date.setUTCDate(date.getUTCDate() + period);
        break;
      default:
        return null;
    }
    return date;
  };

  exports.parseDate = parseDate = function(value, end) {
    var date, millisecs;
    date = null;
    if (/^\d\d\d\d-[A|S|T|Q]\d$/.test(value)) {
      date = timePeriodToDate(value[5], +value.slice(0, 4), +value[6], end);
    } else if (/^\d\d\d\d-[M|W]\d\d$/.test(value)) {
      date = timePeriodToDate(value[5], +value.slice(0, 4), +value.slice(6, 8), end);
    } else if (/^\d\d\d\d-D\d\d\d$/.test(value)) {
      date = timePeriodToDate(value[5], +value.slice(0, 4), +value.slice(6, 9), end);
    } else {
      millisecs = Date.parse(value);
      if (isNaN(millisecs)) {
        return null;
      }
      date = new Date(millisecs);
      if (end) {
        switch (value.length) {
          case 4:
            date.setUTCFullYear(date.getUTCFullYear() + 1);
            break;
          case 7:
            date.setUTCMonth(date.getUTCMonth() + 1);
            break;
          case 10:
            date.setUTCDate(date.getUTCDate() + 1);
        }
      }
    }
    if ((date != null) && end) {
      date.setUTCSeconds(date.getUTCSeconds() - 1);
    }
    return date;
  };

  exports.parseFlowRef = parseFlowRef = function(flowRefStr, request, response) {
    var flowRef, regex;
    if (!(flowRefStr != null)) {
      response.result.errors.push('Mandatory parameter flowRef is missing');
      response.statusCode = 400;
      return;
    }
    regex = /^(([A-z0-9_@$\-]+)|(([A-z][A-z0-9_\-]*(\.[A-z][A-z0-9_\-]*)*)(\,[A-z0-9_@$\-]+)(\,(latest|([0-9]+(\.[0-9]+)*)))?))$/;
    if (!regex.test(flowRefStr)) {
      response.result.errors.push("Invalid parameter flowRef " + flowRefStr);
      response.statusCode = 400;
      return;
    }
    flowRef = flowRefStr.split(',');
    if (flowRef.length === 1) {
      flowRef[1] = flowRef[0];
      flowRef[0] = 'all';
    }
    if (!(flowRef[2] != null) || flowRef[2] === '') {
      flowRef[2] = 'latest';
    }
    return request.query.flowRef = {
      agencyID: flowRef[0],
      id: flowRef[1],
      version: flowRef[2]
    };
  };

  exports.parseKey = parseKey = function(keyStr, request, response) {
    var code, codes, dim, dims, i, key, regex, _i, _j, _len, _len1;
    if (keyStr == null) {
      keyStr = 'all';
    }
    if (keyStr === 'all') {
      request.query.key = 'all';
      return;
    }
    regex = /^(([A-Za-z0-9_@$\-]+([+][A-Za-z0-9_@$\-]+)*)?([.]([A-Za-z0-9_@$\-]+([+][A-Za-z0-9_@$\-]+)*)?)*)$/;
    if (!regex.test(keyStr)) {
      response.result.errors.push("Invalid parameter flowRef " + keyStr);
      response.statusCode = 400;
      return;
    }
    key = [];
    dims = keyStr.split('.');
    for (i = _i = 0, _len = dims.length; _i < _len; i = ++_i) {
      dim = dims[i];
      codes = dim.split('+');
      key[i] = [];
      for (_j = 0, _len1 = codes.length; _j < _len1; _j++) {
        code = codes[_j];
        if (code !== '') {
          key[i].push(code);
        }
      }
      if (-1 < dim.indexOf('+') && key[i].length === 0) {
        response.result.errors.push("Invalid parameter key " + keyStr);
        response.statusCode = 400;
        return;
      }
    }
    return request.query.key = key;
  };

  exports.parseProviderRef = parseProviderRef = function(providerRefStr, request, response) {
    var providerRef, regex;
    if (providerRefStr == null) {
      providerRefStr = 'all';
    }
    regex = /^(([A-z][A-z0-9_\-]*(\.[A-z][A-z0-9_\-]*)*\,)?([A-z0-9_@$\-]+))$/;
    if (!regex.test(providerRefStr)) {
      response.result.errors.push("Invalid parameter providerRef " + providerRefStr);
      response.statusCode = 400;
      return;
    }
    providerRef = providerRefStr.split(',');
    switch (providerRef.length) {
      case 1:
        if (providerRef[0] !== 'all') {
          providerRef[1] = providerRef[0];
          providerRef[0] = 'all';
        }
    }
    if (!(providerRef[0] != null) || providerRef[0] === '') {
      providerRef[0] = 'all';
    }
    if (!(providerRef[1] != null) || providerRef[1] === '') {
      providerRef[1] = 'all';
    }
    if (providerRef.length !== 2) {
      response.result.errors.push("Invalid parameter providerRef " + providerRefStr);
      response.statusCode = 400;
      return;
    }
    return request.query.providerRef = {
      agencyID: providerRef[0],
      id: providerRef[1]
    };
  };

  exports.parseQueryParams = parseQueryParams = function(request, response) {
    var date, n, param, parameters, value;
    parameters = url.parse(request.url, true, false).query;
    request.query.dimensionAtObservation = 'AllDimensions';
    for (param in parameters) {
      value = parameters[param];
      switch (param) {
        case 'startPeriod':
        case 'endPeriod':
          date = parseDate(value, param === 'endPeriod');
          if (date != null) {
            request.query[param] = date;
            continue;
          }
          break;
        case 'firstNObservations':
        case 'lastNObservations':
          n = ~Number(value);
          if (String(n) === value && n >= 0) {
            request.query[param] = n;
            continue;
          }
          break;
        case 'updatedAfter':
          response.statusCode = 501;
          return;
        case 'dimensionAtObservation':
          request.query[param] = value;
          continue;
        case 'detail':
          switch (value) {
            case 'full':
            case 'dataonly':
            case 'nodata':
            case 'serieskeysonly':
              request.query[param] = value;
              continue;
          }
      }
      response.result.errors.push("Invalid query parameter " + param + " value " + value);
      response.statusCode = 400;
      return;
    }
  };

  parseDataQuery = function(path, request, response) {
    parseFlowRef(path[2], request, response);
    if (response.statusCode !== 200) {
      return;
    }
    parseKey(path[3], request, response);
    if (response.statusCode !== 200) {
      return;
    }
    parseProviderRef(path[4], request, response);
    if (response.statusCode !== 200) {
      return;
    }
    parseQueryParams(request, response);
    if (response.statusCode !== 200) {

    }
  };

  parse = function(request, response) {
    var path;
    request.query = {};
    path = url.parse(request.url, false, false).pathname.split('/');
    if (path[1] === 'auth') {
      path.shift();
    }
    request.query.resource = path[1];
    switch (request.query.resource) {
      case 'data':
        return parseDataQuery(path, request, response);
      default:
        response.statusCode = 501;
    }
  };

  findDataFlow = function(request, response) {
    var found;
    found = true;
    found &= (function() {
      switch (request.query.flowRef.agencyID) {
        case 'all':
        case 'ECB':
          return true;
        default:
          return false;
      }
    })();
    found &= (function() {
      switch (request.query.flowRef.id) {
        case 'ECB_ICP1':
          return true;
        default:
          return false;
      }
    })();
    found &= (function() {
      switch (request.query.flowRef.version) {
        case 'latest':
          return true;
        default:
          return false;
      }
    })();
    found &= (function() {
      switch (request.query.providerRef.agencyID) {
        case 'ECB':
        case 'all':
          return true;
        default:
          return false;
      }
    })();
    found &= (function() {
      switch (request.query.providerRef.id) {
        case 'ECB':
        case 'all':
          return true;
        default:
          return false;
      }
    })();
    if (!found) {
      response.statusCode = 404;
      response.result.errors.push("Data flow not found");
      return;
    }
    return dataset;
  };

  addCodesToQuery = function(request, response, msg) {
    var code, dim, endDate, i, index, j, keyCodes, period, query, startDate, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _len5, _len6, _len7, _m, _n, _o, _p, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6;
    query = [];
    _ref = msg.dimensions.id;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      dim = _ref[_i];
      query.push([]);
    }
    _ref1 = msg.dimensions.id;
    for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
      dim = _ref1[i];
      if (msg.dimensions[dim].type !== 'time') {
        continue;
      }
      _ref2 = msg.dimensions[dim].codes.id;
      for (j = _k = 0, _len2 = _ref2.length; _k < _len2; j = ++_k) {
        period = _ref2[j];
        if (request.query.startPeriod != null) {
          startDate = parseDate(period, false);
          if (!(request.query.startPeriod <= startDate)) {
            continue;
          }
        }
        if (request.query.endPeriod != null) {
          endDate = parseDate(period, true);
          if (!(endDate <= request.query.endPeriod)) {
            continue;
          }
        }
        query[i].push(j);
      }
      break;
    }
    if (request.query.key === 'all') {
      _ref3 = msg.dimensions.id;
      for (i = _l = 0, _len3 = _ref3.length; _l < _len3; i = ++_l) {
        dim = _ref3[i];
        if (msg.dimensions[dim].type === 'time') {
          continue;
        }
        _ref4 = msg.dimensions[dim].codes.id;
        for (j = _m = 0, _len4 = _ref4.length; _m < _len4; j = ++_m) {
          code = _ref4[j];
          query[i].push(j);
        }
      }
      return query;
    }
    if (request.query.key.length !== msg.dimensions.id.length - 1) {
      response.result.errors.push("Invalid number of dimensions in parameter key");
      response.statusCode = 400;
      return;
    }
    _ref5 = request.query.key;
    for (i = _n = 0, _len5 = _ref5.length; _n < _len5; i = ++_n) {
      keyCodes = _ref5[i];
      dim = msg.dimensions.id[i];
      if (keyCodes.length === 0) {
        _ref6 = msg.dimensions[dim].codes.id;
        for (j = _o = 0, _len6 = _ref6.length; _o < _len6; j = ++_o) {
          code = _ref6[j];
          query[i].push(j);
        }
        continue;
      }
      for (_p = 0, _len7 = keyCodes.length; _p < _len7; _p++) {
        code = keyCodes[_p];
        if (msg.dimensions[dim].codes[code] == null) {
          continue;
        }
        index = msg.dimensions[dim].codes[code].index;
        if (0 <= index) {
          query[i].push(index);
        }
      }
    }
    return query;
  };

  query = function(msg, request, response) {
    var attr, attrCodeMapping, attrIndex, code, codeIndex, codeMap, codes, codesInQuery, codesWithData, dim, dimPos, i, index, j, key, length, m, map, matchingObs, msgCount, msgMultipliers, msgSize, n, obsIndex, pivot, pivotCount, pivotDimPos, pivotIndex, pivotMultipliers, pivotSubIndex, pos, queryMultipliers, querySize, resultCodeLengths, resultCount, resultMultipliers, rslt, value, _aa, _ab, _ac, _base, _i, _j, _k, _l, _len, _len1, _len10, _len11, _len12, _len13, _len14, _len15, _len16, _len2, _len3, _len4, _len5, _len6, _len7, _len8, _len9, _m, _n, _o, _p, _q, _r, _ref, _ref1, _ref10, _ref11, _ref12, _ref13, _ref14, _ref15, _ref16, _ref17, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9, _results, _s, _t, _u, _v, _w, _x, _y, _z;
    rslt = response.result;
    codesInQuery = addCodesToQuery(request, response, msg);
    if (response.statusCode !== 200) {
      return;
    }
    msgSize = 1;
    msgMultipliers = [];
    _ref = msg.dimensions.id.slice().reverse();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      dim = _ref[_i];
      msgMultipliers.push(msgSize);
      msgSize *= msg.dimensions[dim].codes.id.length;
    }
    msgMultipliers.reverse();
    querySize = 1;
    queryMultipliers = [];
    codesWithData = [];
    for (_j = 0, _len1 = codesInQuery.length; _j < _len1; _j++) {
      codes = codesInQuery[_j];
      queryMultipliers.push(querySize);
      querySize *= codes.length;
      codesWithData.push({});
    }
    if (querySize === 0) {
      response.statusCode = 404;
      response.result.errors.push('Observations not found');
      return;
    }
    matchingObs = 0;
    for (i = _k = 0, _ref1 = querySize - 1; 0 <= _ref1 ? _k <= _ref1 : _k >= _ref1; i = 0 <= _ref1 ? ++_k : --_k) {
      key = [];
      obsIndex = 0;
      for (n = _l = 0, _len2 = codesInQuery.length; _l < _len2; n = ++_l) {
        codes = codesInQuery[n];
        index = Math.floor(i / queryMultipliers[n]) % codes.length;
        key.push(codes[index]);
        obsIndex += codes[index] * msgMultipliers[n];
      }
      if (msg.measure[obsIndex] == null) {
        continue;
      }
      for (j = _m = 0, _len3 = key.length; _m < _len3; j = ++_m) {
        pos = key[j];
        if ((_ref2 = (_base = codesWithData[j])[pos]) == null) {
          _base[pos] = 0;
        }
        codesWithData[j][pos] += 1;
      }
      matchingObs += 1;
    }
    if (matchingObs === 0) {
      response.statusCode = 404;
      response.result.errors.push('Observations not found');
      return;
    }
    if (request.query.dimensionAtObservation !== 'AllDimensions') {
      if (msg.dimensions.id.indexOf(request.query.dimensionAtObservation) === -1) {
        response.statusCode = 400;
        response.result.errors.push("Invalid value for parameter dimensionAtObservation " + request.query.dimensionAtObservation);
        return;
      }
    }
    rslt.dimensions = {
      id: msg.dimensions.id,
      size: [],
      dimensionAtObservation: request.query.dimensionAtObservation
    };
    _ref3 = msg.dimensions.id;
    for (i = _n = 0, _len4 = _ref3.length; _n < _len4; i = ++_n) {
      dim = _ref3[i];
      rslt.dimensions[dim] = {
        id: msg.dimensions[dim].id,
        codes: {
          id: []
        },
        name: msg.dimensions[dim].name,
        type: msg.dimensions[dim].type,
        role: msg.dimensions[dim].role,
        index: i
      };
      _ref4 = Object.keys(codesWithData[i]);
      for (j = _o = 0, _len5 = _ref4.length; _o < _len5; j = ++_o) {
        pos = _ref4[j];
        code = msg.dimensions[dim].codes.id[pos];
        rslt.dimensions[dim].codes.id.push(code);
        rslt.dimensions[dim].codes[code] = {
          index: j,
          id: msg.dimensions[dim].codes[code].id,
          name: msg.dimensions[dim].codes[code].name
        };
        if (msg.dimensions[dim].codes[code].start != null) {
          rslt.dimensions[dim].codes[code].start = msg.dimensions[dim].codes[code].start;
        }
        if (msg.dimensions[dim].codes[code].end != null) {
          rslt.dimensions[dim].codes[code].end = msg.dimensions[dim].codes[code].end;
        }
      }
      rslt.dimensions.size[i] = rslt.dimensions[dim].codes.id.length;
    }
    if (request.query.detail === 'serieskeysonly') {
      return;
    }
    if (request.query.detail !== 'nodata') {
      codeMap = [];
      _ref5 = msg.dimensions.id;
      for (n = _p = 0, _len6 = _ref5.length; _p < _len6; n = ++_p) {
        dim = _ref5[n];
        map = [];
        _ref6 = rslt.dimensions[dim].codes.id;
        for (m = _q = 0, _len7 = _ref6.length; _q < _len7; m = ++_q) {
          code = _ref6[m];
          map.push(msg.dimensions[dim].codes[code].index);
        }
        codeMap.push(map);
      }
      resultCount = 1;
      resultMultipliers = [];
      _ref7 = rslt.dimensions.id.slice().reverse();
      for (_r = 0, _len8 = _ref7.length; _r < _len8; _r++) {
        dim = _ref7[_r];
        resultMultipliers.push(resultCount);
        resultCount *= rslt.dimensions[dim].codes.id.length;
      }
      resultMultipliers.reverse();
      rslt.measure = [];
      for (i = _s = 0, _ref8 = resultCount - 1; 0 <= _ref8 ? _s <= _ref8 : _s >= _ref8; i = 0 <= _ref8 ? ++_s : --_s) {
        obsIndex = 0;
        for (n = _t = 0, _len9 = codeMap.length; _t < _len9; n = ++_t) {
          codes = codeMap[n];
          index = Math.floor(i / resultMultipliers[n]) % codes.length;
          obsIndex += codes[index] * msgMultipliers[n];
        }
        rslt.measure[i] = msg.measure[obsIndex];
      }
    }
    if (rslt.dimensions.dimensionAtObservation !== 'AllDimensions') {
      pivot = [];
      pivotDimPos = rslt.dimensions.id.indexOf(rslt.dimensions.dimensionAtObservation);
      resultCodeLengths = [];
      pivotMultipliers = [];
      pivotCount = 1;
      _ref9 = rslt.dimensions.id;
      for (n = _u = 0, _len10 = _ref9.length; _u < _len10; n = ++_u) {
        dim = _ref9[n];
        resultCodeLengths.push(rslt.dimensions[dim].codes.id.length);
        if (n === pivotDimPos) {
          continue;
        }
        pivotMultipliers[n] = pivotCount;
        pivotCount *= rslt.dimensions[dim].codes.id.length;
      }
      for (i = _v = 0, _ref10 = resultCount - 1; 0 <= _ref10 ? _v <= _ref10 : _v >= _ref10; i = 0 <= _ref10 ? ++_v : --_v) {
        obsIndex = 0;
        pivotIndex = 0;
        pivotSubIndex = 0;
        for (n = _w = 0, _len11 = resultCodeLengths.length; _w < _len11; n = ++_w) {
          length = resultCodeLengths[n];
          codeIndex = Math.floor(i / resultMultipliers[n]) % length;
          obsIndex += codeIndex * resultMultipliers[n];
          if (n === pivotDimPos) {
            pivotSubIndex = codeIndex;
          } else {
            pivotIndex += codeIndex * pivotMultipliers[n];
          }
        }
        if (msg.measure[obsIndex] != null) {
          if ((_ref11 = pivot[pivotIndex]) == null) {
            pivot[pivotIndex] = [];
          }
          pivot[pivotIndex][pivotSubIndex] = rslt.measure[obsIndex];
        }
      }
      rslt.measure = pivot;
    }
    if (request.query.detail === 'dataonly') {
      return;
    }
    _ref12 = msg.attributes.id;
    _results = [];
    for (_x = 0, _len12 = _ref12.length; _x < _len12; _x++) {
      attr = _ref12[_x];
      attrCodeMapping = [];
      _ref13 = msg.attributes[attr].dimension;
      for (_y = 0, _len13 = _ref13.length; _y < _len13; _y++) {
        dim = _ref13[_y];
        dimPos = msg.dimensions.id.indexOf(dim);
        attrCodeMapping.push(codeMap[dimPos]);
      }
      resultCount = 1;
      resultMultipliers = [];
      _ref14 = msg.attributes[attr].dimension.slice().reverse();
      for (_z = 0, _len14 = _ref14.length; _z < _len14; _z++) {
        dim = _ref14[_z];
        resultMultipliers.push(resultCount);
        resultCount *= rslt.dimensions[dim].codes.id.length;
      }
      resultMultipliers.reverse();
      msgCount = 1;
      msgMultipliers = [];
      _ref15 = msg.attributes[attr].dimension.slice().reverse();
      for (_aa = 0, _len15 = _ref15.length; _aa < _len15; _aa++) {
        dim = _ref15[_aa];
        msgMultipliers.push(msgCount);
        msgCount *= msg.dimensions[dim].codes.id.length;
      }
      msgMultipliers.reverse();
      value = [];
      for (i = _ab = 0, _ref16 = resultCount - 1; 0 <= _ref16 ? _ab <= _ref16 : _ab >= _ref16; i = 0 <= _ref16 ? ++_ab : --_ab) {
        attrIndex = 0;
        for (n = _ac = 0, _len16 = attrCodeMapping.length; _ac < _len16; n = ++_ac) {
          codes = attrCodeMapping[n];
          index = Math.floor(i / resultMultipliers[n]) % codes.length;
          attrIndex += codes[index] * msgMultipliers[n];
        }
        if (msg.attributes[attr].value[attrIndex] == null) {
          continue;
        }
        value[i] = msg.attributes[attr].value[attrIndex];
      }
      if (value.length === 0 && msg.attributes[attr]["default"] === null) {
        continue;
      }
      if ((_ref17 = rslt.attributes) == null) {
        rslt.attributes = {
          id: []
        };
      }
      rslt.attributes.id.push(attr);
      _results.push(rslt.attributes[attr] = {
        id: msg.attributes[attr].id,
        name: msg.attributes[attr].name,
        mandatory: msg.attributes[attr].mandatory,
        role: msg.attributes[attr].role,
        dimension: msg.attributes[attr].dimension,
        "default": msg.attributes[attr]["default"],
        value: value,
        codes: msg.attributes[attr].codes
      });
    }
    return _results;
  };

  validateRequest = function(request, response) {
    var auth, encoding, header, matches, mediaTypes, methods, parts, password, path, token, type, username, _i, _len;
    methods = ['GET', 'HEAD', 'OPTIONS'];
    mediaTypes = ['application/json', 'application/*', '*/*'];
    response.setHeader('Allow', methods.join(', '));
    response.setHeader('Access-Control-Allow-Methods', methods.join(', '));
    if (methods.indexOf(request.method) === -1) {
      response.statusCode = 405;
      response.result.errors.push('Supported methods: ' + methods.join(', '));
      return;
    }
    if (request.headers['accept'] != null) {
      matches = 0;
      for (_i = 0, _len = mediaTypes.length; _i < _len; _i++) {
        type = mediaTypes[_i];
        matches += request.headers['accept'].indexOf(type) + 1;
      }
      if (matches === 0) {
        response.statusCode = 406;
        response.result.errors.push('Supported media types: ' + mediaTypes.join(','));
        return;
      }
    }
    encoding = request.headers['accept-encoding'];
    if (encoding != null) {
      if (encoding.match(/\bdeflate\b/)) {
        response.setHeader('Content-Encoding', 'deflate');
      } else if (encoding.match(/\bgzip\b/)) {
        response.setHeader('Content-Encoding', 'gzip');
      }
    }
    if (request.headers['access-control-request-headers'] != null) {
      response.setHeader('access-control-allow-headers', request.headers['access-control-request-headers']);
    }
    path = url.parse(request.url, false, false).pathname.split('/');
    if (path[1] === 'auth') {
      header = request.headers['authorization'] || '';
      token = header.split(/\s+/).pop() || '';
      auth = new Buffer(token, 'base64').toString();
      parts = auth.split(/:/);
      username = parts[0];
      password = parts[1];
      if (username !== 'test' || password !== 'test') {
        response.setHeader('WWW-Authenticate', 'BASIC realm="data/ECB,ECB_ICP1"');
        response.statusCode = 401;
        response.result.errors.push('authorization required');
      }
    }
  };

  compressResponse = function(request, response) {
    var body, sendResponse;
    sendResponse = function(err, body) {
      var encoding;
      if (err != null) {
        response.statusCode = 500;
        response.end();
        return;
      }
      response.setHeader('X-Runtime', new Date() - response.start);
      if (body != null) {
        if (Buffer.isBuffer(body)) {
          response.setHeader('Content-Length', body.length);
        } else {
          response.setHeader('Content-Length', Buffer.byteLength(body));
        }
        if (request.method === 'GET') {
          response.end(body);
        } else {
          response.end();
        }
      } else {
        response.setHeader('Content-Length', 0);
        response.end();
      }
      encoding = response.getHeader('Content-Encoding');
      if (encoding == null) {
        encoding = '';
      }
      log("" + request.method + " " + request.url + " " + response.statusCode + " " + encoding);
    };
    switch (request.method) {
      case 'OPTIONS':
        return sendResponse();
      case 'GET':
      case 'HEAD':
        body = JSON.stringify(response.result, null, 2);
        switch (response.getHeader('Content-Encoding')) {
          case 'deflate':
            return zlib.deflate(body, sendResponse);
          case 'gzip':
            return zlib.gzip(body, sendResponse);
          default:
            return sendResponse(void 0, body);
        }
    }
  };

  handleRequest = function(request, response) {
    var dataflow;
    response.start = new Date();
    response.setHeader('X-Powered-By', "Node.js/" + process.version);
    response.setHeader('Server', "" + SERVER_NAME + "/" + SERVER_VERSION);
    response.setHeader('Cache-Control', 'no-cache, no-store');
    response.setHeader('Pragma', 'no-cache');
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Content-Type', 'application/json');
    response.setHeader('Content-Language', 'en');
    response.statusCode = 200;
    response.result = {
      'sdmx-proto-json': dataset['sdmx-proto-json'],
      id: "IREF" + (process.hrtime()[0]) + (process.hrtime()[1]),
      test: true,
      prepared: (new Date()).toISOString(),
      errors: []
    };
    validateRequest(request, response);
    if (response.statusCode === 200) {
      parse(request, response);
    }
    if (response.statusCode === 200) {
      dataflow = findDataFlow(request, response);
    }
    if (request.method === 'OPTIONS') {
      response.setHeader('Content-Length', 0);
    } else {
      if (response.statusCode === 200) {
        query(dataflow, request, response);
      }
      if (response.statusCode === 200) {
        response.result.name = dataset.name;
        response.result.errors = null;
      }
    }
    return compressResponse(request, response);
  };

  log('starting');

  dataset = loadDataset(DATA_FILE);

  http.createServer(handleRequest).listen(PORT_NUMBER);

  log("listening on port " + PORT_NUMBER);

}).call(this);
