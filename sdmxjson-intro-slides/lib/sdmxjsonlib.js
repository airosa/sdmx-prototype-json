// Generated by CoffeeScript 1.6.3
(function() {
  var KEY_SEPARATOR, lib, root, _mapComponents;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  KEY_SEPARATOR = ':';

  lib = {
    request: {},
    response: {}
  };

  lib.version = '0.2.0';

  lib.response.identity = function(obj) {
    return obj;
  };

  lib.response._normalizeSdmxIdString = function(id) {
    var normalizeIdPart;
    normalizeIdPart = function(s, i) {
      if (i === 0) {
        return s;
      } else {
        return s.substr(0, 1).toUpperCase() + s.substr(1);
      }
    };
    return id.toLowerCase().split('_').map(normalizeIdPart).join('');
  };

  _mapComponents = function(obj, ignoreDatasetLevel, iterator) {
    var key, value, _ref, _ref1, _results;
    _ref = obj.structure.dimensions;
    for (key in _ref) {
      value = _ref[key];
      if (key === 'dataSet' && ignoreDatasetLevel) {
        continue;
      }
      value.forEach(function(d) {
        return iterator(d, 'dimension', key);
      });
    }
    _ref1 = obj.structure.attributes;
    _results = [];
    for (key in _ref1) {
      value = _ref1[key];
      if (key === 'dataSet' && ignoreDatasetLevel) {
        continue;
      }
      _results.push(value.forEach(function(d) {
        return iterator(d, 'attribute', key);
      }));
    }
    return _results;
  };

  lib.response.mapComponentsToArray = function(obj, iterator, ignoreDatasetLevel, context) {
    var results, _iterator;
    if (iterator == null) {
      iterator = lib.response.identity;
    }
    if (ignoreDatasetLevel == null) {
      ignoreDatasetLevel = true;
    }
    results = [];
    if (obj == null) {
      return results;
    }
    _iterator = function(c, type, level) {
      return results.push(iterator.call(context, c, type, level));
    };
    _mapComponents(obj, ignoreDatasetLevel, _iterator);
    return results;
  };

  lib.response.mapComponentsToObject = function(obj, iterator, ignoreDatasetLevel, context) {
    var results, _iterator;
    if (iterator == null) {
      iterator = lib.response.identity;
    }
    if (ignoreDatasetLevel == null) {
      ignoreDatasetLevel = true;
    }
    results = {};
    if (obj == null) {
      return results;
    }
    _iterator = function(c, type, level) {
      var key, value, _ref;
      value = iterator.call(context, c, type, level);
      key = (_ref = value.propertyName) != null ? _ref : value.id;
      return results[key] = value;
    };
    _mapComponents(obj, ignoreDatasetLevel, _iterator);
    return results;
  };

  lib.response.mapDataSetsToArray = function(obj, iterator, ignoreDatasetLevel, context) {
    var a, allAttrs, allDims, attrs, d, dim, dimCount, dimPosition, dims, ds, dsAttrIdx, dsAttrVals, dsDimIdx, dsDimVals, i, key, key1, key2, obsAttrIdx, obsDimIdx, obsKey, resultObs, results, serAttrIdx, serDimIdx, seriesKey, value, value1, value2, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _len5, _len6, _m, _n, _o, _ref, _ref1, _ref10, _ref11, _ref12, _ref13, _ref14, _ref15, _ref16, _ref17, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    if (iterator == null) {
      iterator = lib.response.identity;
    }
    if (ignoreDatasetLevel == null) {
      ignoreDatasetLevel = true;
    }
    results = [];
    if (obj == null) {
      return results;
    }
    dims = obj.structure.dimensions;
    attrs = obj.structure.attributes;
    dimCount = ((_ref = (_ref1 = dims.dataSet) != null ? _ref1.length : void 0) != null ? _ref : 0) + ((_ref2 = (_ref3 = dims.series) != null ? _ref3.length : void 0) != null ? _ref2 : 0) + ((_ref4 = (_ref5 = dims.observation) != null ? _ref5.length : void 0) != null ? _ref4 : 0);
    dimPosition = function(d) {
      var _ref6;
      return (_ref6 = d.keyPosition) != null ? _ref6 : dimCount - 1;
    };
    dsDimIdx = [];
    dsDimVals = [];
    dsAttrIdx = [];
    dsAttrVals = [];
    allDims = [].concat((_ref6 = dims.series) != null ? _ref6 : [], (_ref7 = dims.observation) != null ? _ref7 : []);
    allAttrs = [].concat((_ref8 = attrs.series) != null ? _ref8 : [], (_ref9 = attrs.observation) != null ? _ref9 : []);
    seriesKey = new Array(dimCount);
    obsKey = new Array(dimCount);
    if (dims.dataSet != null) {
      _ref10 = dims.dataSet;
      for (_i = 0, _len = _ref10.length; _i < _len; _i++) {
        d = _ref10[_i];
        seriesKey[dimPosition(d)] = d.values[0].id;
        obsKey[dimPosition(d)] = d.values[0].id;
      }
    }
    if (!ignoreDatasetLevel) {
      if (dims.dataSet != null) {
        _ref11 = dims.dataSet;
        for (_j = 0, _len1 = _ref11.length; _j < _len1; _j++) {
          d = _ref11[_j];
          dsDimVals.push(d.values[0]);
        }
        dsDimIdx = dsDimVals.map(function(d) {
          return 0;
        });
        allDims = dims.dataSet.concat(allDims);
      }
      if (attrs.dataSet != null) {
        _ref12 = attrs.dataSet;
        for (_k = 0, _len2 = _ref12.length; _k < _len2; _k++) {
          a = _ref12[_k];
          dsAttrVals.push(a.values[0]);
        }
        dsAttrIdx = dsAttrVals.map(function(d) {
          return 0;
        });
        allAttrs = attrs.dataSet.concat(allAttrs);
      }
    }
    _ref13 = obj.dataSets;
    for (_l = 0, _len3 = _ref13.length; _l < _len3; _l++) {
      ds = _ref13[_l];
      if (ds.observations != null) {
        _ref14 = ds.observations;
        for (key in _ref14) {
          value = _ref14[key];
          obsDimIdx = key.split(KEY_SEPARATOR).map(function(v) {
            return +v;
          });
          obsAttrIdx = value.slice(1);
          for (i = _m = 0, _len4 = obsDimIdx.length; _m < _len4; i = ++_m) {
            d = obsDimIdx[i];
            dim = dims.observation[i];
            obsKey[dimPosition(dim)] = dim.values[d].id;
          }
          resultObs = {
            _key: obsKey.join(KEY_SEPARATOR),
            _seriesKey: null,
            dimensions: dsDimIdx.concat(obsDimIdx),
            attributes: dsAttrIdx.concat(obsAttrIdx),
            value: value[0]
          };
          results.push(iterator.call(context, resultObs, allDims, allAttrs));
        }
      }
      if (ds.series != null) {
        _ref15 = ds.series;
        for (key1 in _ref15) {
          value1 = _ref15[key1];
          serDimIdx = key1.split(KEY_SEPARATOR).map(function(v) {
            return +v;
          });
          serAttrIdx = (_ref16 = value1.attributes) != null ? _ref16 : [];
          for (i = _n = 0, _len5 = serDimIdx.length; _n < _len5; i = ++_n) {
            d = serDimIdx[i];
            dim = dims.series[i];
            seriesKey[dimPosition(dim)] = obsKey[dimPosition(dim)] = dim.values[d].id;
          }
          serDimIdx = dsDimIdx.concat(serDimIdx);
          serAttrIdx = dsAttrIdx.concat(serAttrIdx);
          _ref17 = value1.observations;
          for (key2 in _ref17) {
            value2 = _ref17[key2];
            obsDimIdx = key2.split(KEY_SEPARATOR).map(function(v) {
              return +v;
            });
            obsAttrIdx = value2.slice(1);
            for (i = _o = 0, _len6 = obsDimIdx.length; _o < _len6; i = ++_o) {
              d = obsDimIdx[i];
              dim = dims.observation[i];
              obsKey[dimPosition(dim)] = dim.values[d].id;
            }
            resultObs = {
              _key: obsKey.join(KEY_SEPARATOR),
              _seriesKey: seriesKey.join(KEY_SEPARATOR),
              dimensions: serDimIdx.concat(obsDimIdx),
              attributes: serAttrIdx.concat(obsAttrIdx),
              value: value2[0]
            };
            results.push(iterator.call(context, resultObs, allDims, allAttrs));
          }
        }
      }
    }
    return results;
  };

  lib.response.obsToStructureSpecific = function(observation, dimensions, attributes) {
    var a, d, i, result, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3;
    result = {
      _key: observation._key,
      _seriesKey: observation._seriesKey,
      obsValue: observation.value
    };
    _ref = observation.dimensions;
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      d = _ref[i];
      result[(_ref1 = dimensions[i].propertyName) != null ? _ref1 : dimensions[i].id] = dimensions[i].values[d];
    }
    _ref2 = observation.attributes;
    for (i = _j = 0, _len1 = _ref2.length; _j < _len1; i = ++_j) {
      a = _ref2[i];
      result[(_ref3 = attributes[i].propertyName) != null ? _ref3 : attributes[i].id] = attributes[i].values[a];
    }
    return result;
  };

  lib.response.addStartAndEndDatesToTimeDimension = function(msg) {
    var key, mapDimension, mapStartAndEnd, value, _ref;
    if (msg == null) {
      return msg;
    }
    mapStartAndEnd = function(value) {
      if (value.start != null) {
        value.startDate = new Date(value.start);
      }
      if (value.end != null) {
        return value.endDate = new Date(value.end);
      }
    };
    mapDimension = function(dim) {
      return dim.values.forEach(mapStartAndEnd);
    };
    _ref = msg.structure.dimensions;
    for (key in _ref) {
      value = _ref[key];
      value.forEach(mapDimension);
    }
    return msg;
  };

  lib.response.addPropertyNamesToComponents = function(msg) {
    var key, value, _ref, _ref1;
    if (msg == null) {
      return msg;
    }
    _ref = msg.structure.dimensions;
    for (key in _ref) {
      value = _ref[key];
      value.forEach(function(d) {
        return d.propertyName = lib.response._normalizeSdmxIdString(d.id);
      });
    }
    _ref1 = msg.structure.attributes;
    for (key in _ref1) {
      value = _ref1[key];
      value.forEach(function(a) {
        return a.propertyName = lib.response._normalizeSdmxIdString(a.id);
      });
    }
    return msg;
  };

  root.sdmxjsonlib = lib;

}).call(this);
