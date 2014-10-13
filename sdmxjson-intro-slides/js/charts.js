(function() {
    root = typeof exports !== "undefined" && exports !== null ? exports : this;

    lib = {};

    console.log('sdmxjsonlib version: ' + sdmxjsonlib.version);
    console.log('d3 version: ' + d3.version);

    lib.makeRequest = function(selector, icpItem) {

        handleResponse = function(error, message) {
            if (error) return console.warn(error);
            console.log('Handling response: ' + message.header.id);

            drawChart(selector, message);

            console.log('Done');
        };

        console.log('Requesting data');

        clearChart(selector);

        var req = new sdmxjsonlib.request.URL();

        req.hostname = 'a-sdw-wsrest.ecb.europa.eu';
        req.path.pathname = 'service';
        req.path.resource = 'data';

        req.path.dataFlow.id = 'ICP';
        req.path.key = [ 'M', [ 'DE', 'FR', 'ES' ], 'N', icpItem, '4', 'INX' ];

        req.query.dimensionAtObservation = 'TIME_PERIOD';
        req.query.startPeriod = '2005';

        console.log(req.href());

        d3.json(req.href()).header('Accept','application/json').get(handleResponse);
    };


    clearChart = function(selector) {
        d3.select(selector).select('.chart-title').text('Please wait, updating chart...');
        d3.select(selector).select('.chart-area').selectAll('*').remove();
        d3.select(selector).select('.chart-footer').text('');
    };


    drawChart = function(selector, message) {
        console.log('Drawing the chart');

        /*
          Map dimensions and attributes (=components) into an object.
          We are mapping all components also the those at the data set level.
          Property names were added to the components earlier.
        */

        var structure = sdmxjsonlib.response.mapComponentsForD3(message);

        /* Map data sets in the sdmx-json message into an array of observations */

        var data = sdmxjsonlib.response.mapDataSetsForD3(message);

        /*
          == Rest of the code uses only d3 functionality. ==
          First group and sort observations into series using the seriesKey
        */

        var sortByEndDate = function(a, b) {
          var ad = a.timePeriod.endDate;
          var bd = b.timePeriod.endDate;
          return ad < bd ? -1 : ad > bd ? 1 : 0;
        };

        var nest = d3.nest();
        nest.key( function(o) { return o._seriesKey; } );
        nest.sortValues(sortByEndDate);
        var series = nest.entries(data);

        /* Calculate minimum and maximum values for both x and y axis */

        var minDate = d3.min( data, function(o) { return o.timePeriod._startDate; } );
        var maxDate = d3.max( data, function(o) { return o.timePeriod._endDate; } );
        var valueExtent = d3.extent( data, function(o) { return o.obsValue; } );

        /* set up svg object */

        var chartRoot = d3.select(selector);
        var rootWidth = chartRoot.attr("width");
        var goldenRatio = 1.618033;

        var margins = [10, 40, 30, 40];
        var width = rootWidth - margins[1] - margins[3];
        var height = (rootWidth / goldenRatio) - margins[0] - margins[2];

        var chart = chartRoot.select('.chart-area')
          .append("svg:svg")
            .attr("width", width + margins[1] + margins[3])
            .attr("height", height + margins[0] + margins[2])
          .append("svg:g")
            .attr("transform", "translate(" + margins[3] + "," + margins[0] + ")");

        /* create axis scales */

        var x = d3.time.scale.utc()
          .domain([minDate,maxDate])
          .range([0, width])
          .nice(d3.time.year);

        var y = d3.scale.linear()
          .domain(valueExtent)
          .range([height, 0])
          .nice();

        /* create xAxis */

        var xAxis = d3.svg.axis()
          .scale(x)
          .tickSize(-(height+10))
          .ticks(d3.time.years,1)
          .tickSubdivide(0)
          .tickFormat(d3.time.format("%Y"))
          .tickPadding(-2);

        chart.append("svg:g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + (height+10) + ")")
          .call(xAxis)
          .selectAll("text")
          .attr("x", 10)
          .attr("dy", 20)
          .attr("text-anchor", null);

        /* create yAxis */

        var yAxis = d3.svg.axis()
          .scale(y)
          .ticks(6)
          .orient("left");

        chart.append("svg:g")
          .attr("class", "y axis")
          .attr("transform", "translate(-10,0)")
          .call(yAxis);

        /*
          Add title to page.
          These components are all at the data set level so we can just take the first value.
        */

        var title = '';
        if (structure.compilation && structure.compilation.values[0] && structure.compilation.values[0].name)
          title = '<abbr title="' + structure.compilation.values[0].name + '">' + structure.icpItem.values[0].name + '</abbr>';
        else
          title = structure.icpItem.values[0].name;

        title = [
          title,
          structure.icpSuffix.values[0].name,
          structure.adjustment.values[0].name,
          structure.unitIndexBase.values[0].name
        ].join(', ');

        chartRoot.select('.chart-title').html(title);

        /* create lines for the series */

        var line = d3.svg.line()
          /*
            Calculate the mid point for each time period to indicate period average.
          */
          .x( function(d) {
              var diff = (d.timePeriod._endDate - d.timePeriod._startDate)/2;
              var midDate = new Date(d.timePeriod._startDate.getTime() + diff);
              return x(midDate);
          })
          .y( function(d) { return y(d.obsValue); } );

        var colours = d3.scale.category10();

        var addSeriesToChart = function(series, position) {

          // Draw the line for the series
          chart.append("svg:path")
            .attr("d", line(series.values))
            .style("stroke", colours(position) )
            .attr("class", "line");

          // Draw the line for the legend
          chart.append("svg:rect")
            .attr("x", 20)
            .attr("y", 20 + (position * 20))
            .attr("height", 2)
            .attr("width", 40)
            .style("stroke", colours(position) );

          /*
            Draw text for the legend. In the request we are only varying
            the reference area so we can use that as the legend text.
            All observations for the series will have the same value so we just pick
            the first one.
          */
          chart.append("svg:text")
            .attr("x", 70)
            .attr("y", 25 + (position * 20))
            .attr("class","series-title")
            .text(series.values[0].refArea.name);
        };

        series.forEach(addSeriesToChart);
    };

    root.charts = lib;

}).call(this);

