// Generated by CoffeeScript 1.3.3
(function() {

  demoModule.controller('MainCtrl', function($scope, $http) {
    var JSONArrayCube, PivotTable, calculateStartAndEndPeriods, onData, onDimensions, onError, onErrorData;
    $scope.version = '0.1.3';
    $scope.state = {
      httpError: false,
      httpErrorData: false,
      dataRequestRunning: false,
      dimensionRequestRunning: false
    };
    $scope.wsName = 'http://live-test-ws.nodejitsu.com';
    $scope.dfName = 'ECB_ICP1';
    $scope.key = '';
    $scope.customParams = '';
    $scope.show = 'data';
    $scope.showMetadata = false;
    $scope.refreshRuntime = null;
    JSONArrayCube = (function() {

      function JSONArrayCube(msg) {
        var attr, attrId, dimId, prev, _i, _j, _len, _len1, _ref, _ref1;
        this.msg = msg;
        this.multipliers = [];
        prev = 1;
        _ref = this.msg.dimensions.id.slice().reverse();
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          dimId = _ref[_i];
          this.multipliers.push(prev);
          prev *= this.msg.dimensions[dimId].codes.id.length;
        }
        this.multipliers.reverse();
        this.dimensions = this.msg.dimensions;
        this.obsAttributes = [];
        _ref1 = this.msg.attributes.id;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          attrId = _ref1[_j];
          attr = this.msg.attributes[attrId];
          if (attr.dimension.length === this.msg.dimensions.id.length) {
            this.obsAttributes.push(attrId);
          }
        }
      }

      JSONArrayCube.prototype.attribute = function(id) {
        return this.msg.attributes[id];
      };

      JSONArrayCube.prototype.observationValue = function(key) {
        var codeIndex, index, j, _i, _len;
        index = 0;
        for (j = _i = 0, _len = key.length; _i < _len; j = ++_i) {
          codeIndex = key[j];
          index += codeIndex * this.multipliers[j];
        }
        return this.msg.measure[index];
      };

      JSONArrayCube.prototype.attributeValue = function(id, key) {
        var attr, attrVal, attributes, dim, dimensions, index, j, _i, _len, _ref, _ref1;
        attrVal = {};
        attributes = this.msg.attributes;
        dimensions = this.msg.dimensions;
        attr = this.msg.attributes[id];
        if (attr == null) {
          return void 0;
        }
        index = 0;
        _ref = attr.dimension;
        for (j = _i = 0, _len = _ref.length; _i < _len; j = ++_i) {
          dim = _ref[j];
          index += key[this.msg.dimensions[dim].index] * attr.multipliers[j];
        }
        attrVal.value = attr.value[index];
        if ((_ref1 = attrVal.value) == null) {
          attrVal.value = attr["default"];
        }
        if (attr.codes != null) {
          attrVal.name = attr.codes[attrVal.value].name;
        }
        return attrVal;
      };

      return JSONArrayCube;

    })();
    PivotTable = (function() {

      function PivotTable() {
        this.data = null;
        this.pageData = [];
        this.pageDims = [];
        this.rowDims = [];
        this.colDims = [];
      }

      PivotTable.prototype.newRow = function() {
        return {
          headers: [],
          data: []
        };
      };

      PivotTable.prototype.addHeadRow = function() {
        this.headrows.push(this.row);
        return this.row = this.newRow();
      };

      PivotTable.prototype.addBodyRow = function() {
        this.bodyrows.push(this.row);
        return this.row = this.newRow();
      };

      PivotTable.prototype.addHeaderCell = function(value, rowspan, colspan) {
        if (rowspan == null) {
          rowspan = 1;
        }
        if (colspan == null) {
          colspan = 1;
        }
        return this.row.headers.push({
          value: value,
          rowspan: rowspan,
          colspan: colspan
        });
      };

      PivotTable.prototype.addDataCell = function(key) {
        var attr, attrId, val, _i, _len, _ref;
        val = {
          decimals: this.data.attributeValue('DECIMALS', key),
          obsVal: this.data.observationValue(key),
          style: {
            'text-align': 'right'
          },
          key: key.join(':'),
          metadata: '',
          hclass: 'cell-normal',
          attributes: []
        };
        if (val.obsVal != null) {
          if (val.decimals != null) {
            val.data = val.obsVal.toFixed(val.decimals.value);
          } else {
            val.data = val.obsVal;
          }
        }
        _ref = this.data.obsAttributes;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          attrId = _ref[_i];
          attr = this.data.attributeValue(attrId, key);
          if (attr == null) {
            continue;
          }
          val.attrName = this.data.attribute(attrId).name;
          val.attributes.push(attr);
          if (0 < val.metadata.length) {
            val.metadata += ', ';
          }
          val.metadata += this.data.attribute(attrId).name + ': ';
          val.metadata += attr.name != null ? attr.name : attr.value;
        }
        if ($scope.show === 'metadata') {
          val.value = val.metadata;
        } else {
          val.value = val.data;
        }
        return this.row.data.push(val);
      };

      PivotTable.prototype.pivotRow = function(pos) {
        var tmp;
        if (pos === 0) {
          this.colDims.splice(0, 0, this.rowDims.shift());
        } else {
          tmp = this.rowDims[pos];
          this.rowDims[pos] = this.rowDims[pos - 1];
          this.rowDims[pos - 1] = tmp;
        }
        return this.rebuild();
      };

      PivotTable.prototype.pivotCol = function(pos) {
        var tmp;
        if (pos === this.colDims.length - 1) {
          this.rowDims.push(this.colDims.pop());
        } else {
          tmp = this.colDims[pos];
          this.colDims[pos] = this.colDims[pos - 1];
          this.colDims[pos - 1] = tmp;
        }
        return this.rebuild();
      };

      PivotTable.prototype.build = function(data) {
        var colPos, dim, dimId, rowPos, _i, _len, _ref;
        this.data = data;
        this.pageDims = [];
        this.pageData = [];
        this.obsAttributes = [];
        _ref = this.data.dimensions.id;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          dimId = _ref[_i];
          dim = this.data.dimensions[dimId];
          rowPos = this.rowDims.indexOf(dim.id);
          colPos = this.colDims.indexOf(dim.id);
          if (dim.codes.id.length === 1) {
            this.pageDims.push(dim.id);
            this.pageData.push({
              name: dim.name,
              value: dim.codes[dim.codes.id[0]].name
            });
            if (-1 < rowPos) {
              this.rowDims.splice(rowPos, 1);
            }
            if (-1 < colPos) {
              this.colDims.splice(colPos, 1);
            }
            continue;
          }
          if (-1 < rowPos || -1 < colPos) {
            continue;
          }
          if (this.rowDims.length === 0) {
            this.rowDims.push(dim.id);
            continue;
          }
          if (this.colDims.length === 0) {
            this.colDims.push(dim.id);
            continue;
          }
          this.rowDims.push(dim.id);
        }
        return this.rebuild();
      };

      PivotTable.prototype.visualize = function() {
        var cell, max, min, opacity, range, row, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2, _results;
        if ($scope.show !== 'dataColors') {
          return;
        }
        max = null;
        min = null;
        _ref = this.bodyrows;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          row = _ref[_i];
          _ref1 = row.data;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            cell = _ref1[_j];
            if (cell.obsVal == null) {
              continue;
            }
            if (max == null) {
              max = cell.obsVal;
            }
            if (min == null) {
              min = cell.obsVal;
            }
            if (max < cell.obsVal) {
              max = cell.obsVal;
            }
            if (cell.obsVal < min) {
              min = cell.obsVal;
            }
          }
        }
        range = max - min;
        _ref2 = this.bodyrows;
        _results = [];
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          row = _ref2[_k];
          _results.push((function() {
            var _l, _len3, _ref3, _results1;
            _ref3 = row.data;
            _results1 = [];
            for (_l = 0, _len3 = _ref3.length; _l < _len3; _l++) {
              cell = _ref3[_l];
              if (!cell.obsVal) {
                continue;
              }
              opacity = 1 - ((max - cell.obsVal) / range);
              _results1.push(cell.style.background = 'rgba(70,136,71,' + opacity + ')');
            }
            return _results1;
          })());
        }
        return _results;
      };

      PivotTable.prototype.rebuild = function() {
        var cellkey, code, codeIndex, codeIndexPrev, colCount, colLengths, colSteps, dim, dimId, i, id, j, k, length, repeat, rowCount, rowLengths, rowSteps, start, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _len5, _len6, _m, _n, _o, _p, _q, _r, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _s, _t;
        start = new Date();
        this.headrows = [];
        this.bodyrows = [];
        this.row = this.newRow();
        colSteps = [];
        colLengths = [];
        colCount = 1;
        _ref = this.colDims.slice().reverse();
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          dimId = _ref[_i];
          colSteps.push(colCount);
          length = this.data.dimensions[dimId].codes.id.length;
          colCount *= length;
          colLengths.push(length);
        }
        colSteps.reverse();
        colLengths.reverse();
        rowSteps = [];
        rowLengths = [];
        rowCount = 1;
        _ref1 = this.rowDims.slice().reverse();
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          dimId = _ref1[_j];
          rowSteps.push(rowCount);
          length = this.data.dimensions[dimId].codes.id.length;
          rowCount *= length;
          rowLengths.push(length);
        }
        rowSteps.reverse();
        rowLengths.reverse();
        this.addHeaderCell(null, this.colDims.length, this.rowDims.length);
        if (this.colDims.length === 0) {
          this.addHeaderCell(null);
          this.addHeadRow();
        } else {
          _ref2 = this.colDims;
          for (i = _k = 0, _len2 = _ref2.length; _k < _len2; i = ++_k) {
            dimId = _ref2[i];
            repeat = i === 0 ? 1 : colLengths[i - 1];
            for (j = _l = 0; 0 <= repeat ? _l < repeat : _l > repeat; j = 0 <= repeat ? ++_l : --_l) {
              _ref3 = this.data.dimensions[dimId].codes.id;
              for (_m = 0, _len3 = _ref3.length; _m < _len3; _m++) {
                id = _ref3[_m];
                this.addHeaderCell(this.data.dimensions[dimId].codes[id].name, 1, colSteps[i]);
              }
            }
            this.addHeadRow();
          }
        }
        cellkey = [];
        for (i = _n = 0, _ref4 = this.data.dimensions.id.length; 0 <= _ref4 ? _n < _ref4 : _n > _ref4; i = 0 <= _ref4 ? ++_n : --_n) {
          cellkey[i] = 0;
        }
        if (this.rowDims.length === 0) {
          this.addHeaderCell(null);
          for (j = _o = 0; 0 <= colCount ? _o < colCount : _o > colCount; j = 0 <= colCount ? ++_o : --_o) {
            _ref5 = this.colDims;
            for (k = _p = 0, _len4 = _ref5.length; _p < _len4; k = ++_p) {
              dimId = _ref5[k];
              dim = this.data.dimensions[dimId];
              codeIndex = Math.floor(j / colSteps[k]) % colLengths[k];
              cellkey[dim.index] = codeIndex;
            }
            this.addDataCell(cellkey);
          }
          this.addBodyRow();
        } else {
          for (i = _q = 0; 0 <= rowCount ? _q < rowCount : _q > rowCount; i = 0 <= rowCount ? ++_q : --_q) {
            _ref6 = this.rowDims;
            for (j = _r = 0, _len5 = _ref6.length; _r < _len5; j = ++_r) {
              dimId = _ref6[j];
              dim = this.data.dimensions[dimId];
              codeIndex = Math.floor(i / rowSteps[j]) % rowLengths[j];
              codeIndexPrev = Math.floor((i - 1) / rowSteps[j]) % rowLengths[j];
              cellkey[dim.index] = codeIndex;
              if (codeIndex !== codeIndexPrev) {
                code = this.data.dimensions[dimId].codes.id[codeIndex];
                this.addHeaderCell(this.data.dimensions[dimId].codes[code].name, rowSteps[j], 1);
              }
            }
            for (j = _s = 0; 0 <= colCount ? _s < colCount : _s > colCount; j = 0 <= colCount ? ++_s : --_s) {
              _ref7 = this.colDims;
              for (k = _t = 0, _len6 = _ref7.length; _t < _len6; k = ++_t) {
                dimId = _ref7[k];
                dim = this.data.dimensions[dimId];
                codeIndex = Math.floor(j / colSteps[k]) % colLengths[k];
                cellkey[dim.index] = codeIndex;
              }
              this.addDataCell(cellkey);
            }
            this.addBodyRow();
          }
        }
        this.visualize();
        return $scope.refreshRuntime = new Date() - start;
      };

      return PivotTable;

    })();
    $scope.pivotTable = new PivotTable();
    $scope.getDimensions = function() {
      $scope.state.httpError = false;
      $scope.state.dimensionRequestRunning = true;
      return $http.get($scope.dimUrl).success(onDimensions).error(onError);
    };
    $scope.getData = function() {
      $scope.startRequest = new Date();
      $scope.state.httpErrorData = false;
      $scope.state.dataRequestRunning = true;
      return $http.get($scope.dataUrl).success(onData).error(onErrorData);
    };
    onDimensions = function(data, status, headers, config) {
      var code, codeId, dim, dimId, dimensions, _i, _j, _len, _len1, _ref, _ref1;
      $scope.state.dimensionRequestRunning = false;
      $scope.state.httpError = false;
      $scope.pivotTable = new PivotTable();
      $scope.response = {
        status: status,
        headers: headers
      };
      dimensions = $scope.dimensions = data.dimensions;
      dimensions.seriesKeyDims = [];
      _ref = dimensions.id;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dimId = _ref[_i];
        dim = dimensions[dimId];
        dimensions.seriesKeyDims.push(dimId);
        if (dim.type === 'time') {
          dimensions.timeDimension = dim;
        }
        _ref1 = dim.codes.id;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          codeId = _ref1[_j];
          code = dim.codes[codeId];
          code.checked = false;
          if (dim.type === 'time') {
            dimensions.timeDimension = dim;
            code.start = new Date(code.start);
            code.end = new Date(code.end);
          }
        }
        dim.codes[dim.codes.id[0]].checked = true;
        if (1 < dim.codes.id.length) {
          dim.codes[dim.codes.id[1]].checked = true;
        }
        dim.show = false;
      }
      return $scope.changeCheckedCodes();
    };
    onData = function(data, status, headers, config) {
      var attr, attrId, code, codeId, dim, dimId, prev, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _ref, _ref1, _ref2, _ref3, _ref4;
      $scope.requestRuntime = new Date() - $scope.startRequest;
      $scope.state.httpErrorData = false;
      $scope.state.dataRequestRunning = false;
      $scope.response = {
        status: status,
        headers: headers
      };
      $scope.data = data;
      data.commonDimensions = [];
      data.tableDimensions = {
        rows: [],
        cols: []
      };
      _ref = data.dimensions.id;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dimId = _ref[_i];
        dim = data.dimensions[dimId];
        if (dim.type === 'time') {
          data.dimensions.timeDimension = dim;
          _ref1 = dim.codes.id;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            codeId = _ref1[_j];
            code = dim.codes[codeId];
            code.start = new Date(code.start);
            code.end = new Date(code.end);
          }
        }
      }
      data.dimensions.multipliers = [];
      prev = 1;
      _ref2 = data.dimensions.id.slice().reverse();
      for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
        dim = _ref2[_k];
        data.dimensions.multipliers.push(prev);
        prev *= data.dimensions[dim].codes.id.length;
      }
      data.dimensions.multipliers.reverse();
      _ref3 = data.attributes.id;
      for (_l = 0, _len3 = _ref3.length; _l < _len3; _l++) {
        attrId = _ref3[_l];
        attr = data.attributes[attrId];
        attr.multipliers = [];
        prev = 1;
        _ref4 = attr.dimension.slice().reverse();
        for (_m = 0, _len4 = _ref4.length; _m < _len4; _m++) {
          dim = _ref4[_m];
          attr.multipliers.push(prev);
          prev *= data.dimensions[dim].codes.id.length;
        }
        attr.multipliers.reverse();
      }
      return $scope.pivotTable.build(new JSONArrayCube(data));
    };
    onError = function(data, status, headers, config) {
      $scope.state.dimensionRequestRunning = false;
      $scope.state.httpError = true;
      return $scope.response = {
        status: status,
        headers: headers,
        errors: data.errors
      };
    };
    onErrorData = function(data, status, headers, config) {
      $scope.state.dataRequestRunning = false;
      $scope.state.httpErrorData = true;
      return $scope.response = {
        status: status,
        headers: headers,
        errors: data.errors
      };
    };
    $scope.pivotRow = function(pos) {
      return $scope.pivotTable.pivotRow(pos);
    };
    $scope.pivotCol = function(pos) {
      return $scope.pivotTable.pivotCol(pos);
    };
    $scope.showButtonText = function(show) {
      if (show) {
        return 'Hide';
      } else {
        return 'Show';
      }
    };
    $scope.changeDimUrl = function() {
      var params;
      $scope.dimUrl = "" + $scope.wsName + "/data/" + $scope.dfName;
      if ($scope.key.length) {
        $scope.dimUrl += "/" + $scope.key;
      }
      params = [];
      params.push("detail=serieskeysonly");
      if ($scope.customParams.length) {
        params.push($scope.customParams);
      }
      if (params.length) {
        return $scope.dimUrl += "?" + params.join('&');
      }
    };
    $scope.changeDimUrl();
    $scope.changeCheckedCodes = function() {
      var code, codeId, dim, dimId, dimensions, _i, _j, _len, _len1, _ref, _ref1;
      dimensions = $scope.dimensions;
      _ref = dimensions.id;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dimId = _ref[_i];
        dim = dimensions[dimId];
        dim.codes.checked = [];
        _ref1 = dim.codes.id;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          codeId = _ref1[_j];
          code = dim.codes[codeId];
          if (code.checked) {
            dim.codes.checked.push(code.id);
          }
        }
      }
      return $scope.changeDataUrl();
    };
    $scope.changeDataUrl = function() {
      var codes, dim, dimId, dimensions, i, key, params, periods, _i, _j, _len, _len1, _ref;
      $scope.dataUrl = "" + $scope.wsName + "/data/" + $scope.dfName;
      key = [];
      dimensions = $scope.dimensions;
      _ref = dimensions.id;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        dimId = _ref[i];
        dim = dimensions[dimId];
        if (dim.type === 'time') {
          continue;
        }
        key.push(dim.codes.checked);
      }
      for (i = _j = 0, _len1 = key.length; _j < _len1; i = ++_j) {
        codes = key[i];
        key[i] = codes.join('+');
      }
      $scope.dataUrl += '/' + key.join('.');
      periods = calculateStartAndEndPeriods($scope.dimensions.timeDimension);
      params = [];
      if (periods.length) {
        params.push(periods);
      }
      params.push("dimensionAtObservation=AllDimensions");
      if ($scope.customParams.length) {
        params.push($scope.customParams);
      }
      if (params.length) {
        return $scope.dataUrl += '?' + params.join('&');
      }
    };
    calculateStartAndEndPeriods = function(timeDimension) {
      var code, codeId, endPeriod, params, startPeriod, _i, _len, _ref;
      startPeriod = null;
      endPeriod = null;
      params = '';
      _ref = timeDimension.codes.id;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        codeId = _ref[_i];
        code = timeDimension.codes[codeId];
        if (!code.checked) {
          continue;
        }
        if (startPeriod != null) {
          if (code.start < startPeriod.start) {
            startPeriod = code;
          }
        } else {
          startPeriod = code;
        }
        if (endPeriod != null) {
          if (endPeriod.end < code.end) {
            endPeriod = code;
          }
        } else {
          endPeriod = code;
        }
      }
      if (startPeriod != null) {
        params = 'startPeriod=' + startPeriod.id;
      }
      if (endPeriod != null) {
        params += '&endPeriod=' + endPeriod.id;
      }
      return params;
    };
  });

}).call(this);
