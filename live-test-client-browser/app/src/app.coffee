validationApp = angular.module 'VizApp', []


validationApp.controller 'VizCtrl', ($scope, $http) ->
    $scope.schemaType = 'json-slice'
    $scope.messages = []
    schema = {}
    $scope.topRecords = []
    obsValueDim = {}
    seriesDimensions = []
    observationDimensions = []
    $scope.seriesDisplayDimensions = []
    $scope.observationDisplayDimensions = []
    seriesGroups = []
    observationGroups = []


    $scope.start = () ->
        $scope.seriesDisplayDimensions = []
        $scope.observationDisplayDimensions = []
        $scope.messages = []
        requestData()


    requestData = () ->
        info "Requesting data"

        config =
            method: 'GET'
            url: 'data.json'
            cache: false
            transformResponse: (data) -> data

        $http(config).success(onData).error(onError)


    onData = (data, status, headers, config) ->
        info 'Received data'
        info 'Starting to parse data'

        try
            response = JSON.parse data
        catch error
            severe error
            return

        info "Data sets #{response.dataSets.length}"
        info "Series #{response.dataSets[0].series.length}"

        preProcess response

        $scope.response = response
        $scope.filter = buildCrossFilter response
        info "Crossfilter built #{$scope.filter.size()} records"

        info 'Finished parsing data'

        updateDisplay()

        info 'Finished updating display'
        info 'Done'


    onError = (data, status, headers, config) ->
        try
            json = JSON.parse data
            severe "#{status} #{json.errors}"
        catch err
            severe status


    info = (msg) -> log 'muted', msg

    severe = (msg) -> log 'text-error', "Error: #{msg}"

    log = (style, msg) -> $scope.messages.push class: style, msg: (new Date()).toISOString()[11..22] + ' ' + msg


    buildCrossFilter = (response) ->
        obsArray = []
        for ds in response.dataSets
            for series in ds.series
                for obs in series.observations
                    obsArray.push [ series.dimensions, obs ]

        filter = crossfilter obsArray

        seriesDimensions = []
        seriesGroups = []
        for dim, i in response.structure.packaging.seriesDimensions
            filterDim = filter.dimension (a) -> a[0][i]
            seriesDimensions.push filterDim
            seriesGroups.push filterDim.group()

        observationDimensions = []
        observationGroups = []
        for dim, i in response.structure.packaging.observationDimensions
            filterDim = filter.dimension (a) -> a[1][i]
            observationDimensions.push filterDim
            observationGroups.push filterDim.group()

        obsValueDim = filter.dimension (a) -> a[1][1]

        filter


    $scope.update = (type, index, val) ->
        dims = switch type
            when 'ser' then seriesDimensions
            when 'obs' then observationDimensions

        if val[0] is -1
            dims[index].filterAll()
        else
            dims[index].filterExact val[0]

        updateDisplay()


    updateDisplay = () ->
        for group, i in seriesGroups
            dim = $scope.seriesDisplayDimensions[i]
            for grouping in group.all()
                continue unless grouping.value?
                val = dim.values[grouping.key+1]
                val.title = "#{val.name} (#{grouping.value})"

        for group, i in observationGroups
            dim = $scope.observationDisplayDimensions[i]
            for grouping in group.all()
                continue unless grouping.value?
                val = dim.values[grouping.key+1]
                val.title = "#{val.name} (#{grouping.value})"

        top = obsValueDim.top 50
        $scope.topRecords = []
        for rec in top
            row = []
            for val, i in rec[0]
                row.push $scope.response.structure.packaging.seriesDimensions[i].values[val].name
            for val, i in rec[1][0...-1]
                row.push $scope.response.structure.packaging.observationDimensions[i].values[val].name
            row.push rec[1][-1...][0]
            $scope.topRecords.push row


    preProcess = (response) ->
        $scope.title = response.dataSets[0].name
        $scope.source = response.dataSets[0].provider.name

        for dim in response.structure.packaging.seriesDimensions
            dispDim =
                name: dim.name
                values: [ { name: 'All', index: -1 , title: 'All' } ]

            for val, i in dim.values
                dispDim.values.push { name: val.name, index: i, title: val.name }

            $scope.seriesDisplayDimensions.push dispDim

        for dim in response.structure.packaging.observationDimensions
            dispDim =
                name: dim.name
                values: [ { name: 'All', index: -1, title: 'All' } ]

            for val, i in dim.values
                dispDim.values.push { name: val.name, index: i, title: val.name }

            $scope.observationDisplayDimensions.push dispDim




