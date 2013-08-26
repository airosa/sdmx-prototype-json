(function() {
    root = typeof exports !== "undefined" && exports !== null ? exports : this;

    lib = {};

    lib.makeRequest = function(size) {

        handleResponse = function(error, response) {
            d3.select('#demo-alert').style('opacity','0');

            var startHandle = Date.now();

            var message = JSON.parse(response.responseText);

            var seriesCount = Object.keys(message.dataSets[0].series).length;
            var obsCount = 0;
            for (var seriesKey in message.dataSets[0].series) {
                obsCount += Object.keys(message.dataSets[0].series[seriesKey].observations).length;
            }
            var attrsCount = 0;
            for (var level in message.structure.attributes) {
                for (var attrId in message.structure.attributes[level]) {
                    attrsCount += message.structure.attributes[level].reduce( function(i,a) { return i + a.values.length; }, 0);
                }
            }

            var contentInfo = [
                'Series: ' + seriesCount,
                'Observations: ' + obsCount,
                'Attributes: ' + attrsCount
            ];

            var sizeInfo = [
                'Response: ' + Math.round(response.responseText.length / 1024) + ' KB',
                'Compressed: ' + Math.round(response.getResponseHeader('content-length') / 1024) + ' KB'
            ];

            var speedInfo = [
                'Server: ' + response.getResponseHeader('x-runtime') + ' ms',
                'Network: ' + (startHandle - start -  response.getResponseHeader('x-runtime')) + ' ms',
                'Client: ' + (Date.now() - startHandle) + ' ms',
                'Total: ' + (Date.now() - start) + ' ms'
            ];

            showInfo = function(selector, data) {
                d3.select(selector).selectAll('*').remove();
                d3.select(selector)
                    .append('ul')
                        .attr('class', 'unstyled')
                    .selectAll('li')
                    .data(data)
                    .enter()
                    .append('li')
                        .text( function(d) { return d; });
            };

            showInfo( '#content-' + size, contentInfo );
            showInfo( '#speed-' + size, speedInfo );
            showInfo( '#size-' + size, sizeInfo );
        };

        var keys = {
            small: 'M.AT+FI+DE+FR+ES.N.010000.4.INX',
            medium: 'M..N.010000+020000+030000.4.INX',
            large: 'M.FI+DE+FR+ES.N..4.INX'
        };

        var ws = 'http://live-test-ws-7.nodejitsu.com/data';
        var dataSet = 'ECB_ICP1';
        var params = 'dimensionAtObservation=TIME_PERIOD';
        var url = [ ws, dataSet, keys[size] ].join('/') + '?' + params;

        var start = Date.now();
        d3.select('#demo-alert').style('opacity','1');

        d3.xhr(url, 'application/json', handleResponse);
    };

    root.demo = lib;

}).call(this);
