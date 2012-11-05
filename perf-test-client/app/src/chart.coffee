demoModule.directive 'ghChart', () ->
  
  # constants
  margins = [40, 40, 40, 40]
  width = 800 - margins[1] - margins[3]
  height = 400 - margins[0] - margins[2]

  return {
    restrict: 'E'
    link: (scope, element, attrs) ->

      # set up initial svg object
      chart = d3.select(element[0])
        .append("svg:svg")
        #.attr("width", width)
        #.attr("height", height + margin + 100)
        .attr("width", width + margins[1] + margins[3])
        .attr("height", height + margins[0] + margins[2])
        .append("svg:g")
        .attr("transform", "translate(" + margins[3] + "," + margins[0] + ")");


      scope.$watch attrs.data, (series, oldSeries) ->

        xMax = d3.max series, (obs) -> obs.date
        xMin = d3.min series, (obs) -> obs.date
        yMax = d3.max series, (obs) -> obs.value
        yMin = d3.min series, (obs) -> obs.value

        # create x-axis scale
        x = d3.time.scale.utc()
          .domain([xMin, xMax])
          .range([0, width])
          .nice(d3.time.year)

        # create y-axis scale
        y = d3.scale.linear()
          .domain([yMin, yMax])
          .range([height, 0])
          .nice()
   
        # create line for the data
        line = d3.svg.line()
          .x( (d) -> x(d.date) )
          .y( (d) -> y(d.value) )

        # create xAxis
        xAxis = d3.svg.axis()
          .scale(x)
          .tickSize(-(height+10))
          .ticks(d3.time.years,1)
          .tickSubdivide(0)
          .tickFormat(d3.time.format("%Y"))
          .tickPadding(-2)
        # Add the x-axis.
        chart.append("svg:g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + (height+10) + ")")
          .call(xAxis)
          .selectAll("text")
          .attr("x", 5)
          .attr("dy", null)
          .attr("text-anchor", null);

        # create left yAxis
        yAxisLeft = d3.svg.axis()
          .scale(y)
          .ticks(6)
          .orient("left")
        #Add the y-axis to the left
        chart.append("svg:g")
          .attr("class", "y axis")
          .attr("transform", "translate(-10,0)")
          .call(yAxisLeft)

        # add data to the chart
        chart.append("svg:path")
          .attr("d", line(series))
          .attr("class", "data1")
  }
