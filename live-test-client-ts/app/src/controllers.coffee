demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.1.1'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    $scope.wsName = 'http://live-test-ws.nodejitsu.com'
    #$scope.wsName = 'http://localhost:8081'
    #$scope.wsName = 'http://46.137.144.117/FusionCube/ws'

    $scope.dfName = 'ECB_ICP1'
    #$scope.dfName = 'IMF,PGI,1.0'

    $scope.key = ''
    #$scope.key = '....'

    $scope.customParams = ''
    #$scope.customParams = 'format=samistat'

#-------------------------------------------------------------------------------
# Code for making requests to the WS

    $scope.getDimensions = () ->
        $scope.state.httpError = false
        $scope.state.dimensionRequestRunning = true
        $http.get($scope.dimUrl).success(onDimensions).error(onError)


    $scope.getData = () ->
        $scope.startRequest = new Date()
        $scope.state.httpErrorData = false
        $scope.state.dataRequestRunning = true
        $http.get($scope.dataUrl).success(onData).error(onErrorData)

#-------------------------------------------------------------------------------
# Code for handling responses to requests

    onDimensions = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.httpError = false        

        $scope.response =
            status: status
            headers: headers

        dimensions = $scope.dimensions = data.dimensions

        dimensions.seriesKeyDims = []
        for dimId in dimensions.id
            dim = dimensions[dimId]
            
            if dim.type is 'time'
                dimensions.timeDimension = dim
            else
                dimensions.seriesKeyDims.push dimId

            for codeId in dim.codes.id
                code = dim.codes[codeId]
                code.checked = false
                if dim.type is 'time'
                    code.start = new Date code.start
                    code.end = new Date code.end

            dim.codes[dim.codes.id[0]].checked = true
            dim.show = false

        $scope.changeCheckedCodes()


    onData = (data, status, headers, config) ->
        $scope.requestRuntime = new Date() - $scope.startRequest
        $scope.state.httpErrorData = false
        $scope.state.dataRequestRunning = false

        $scope.response =
            status: status
            headers: headers

        $scope.data = data
        data.commonDimensions = []
        seriesKeyDims = data.dimensions.seriesKeyDims = []
        for dimId in data.dimensions.id
            dim = data.dimensions[dimId]
            
            if dim.type is 'time'
                data.dimensions.timeDimension = dim
                for codeId in dim.codes.id
                    code = dim.codes[codeId]
                    # convert date strings to Javascript dates
                    code.start = new Date code.start
                    code.end = new Date code.end

                continue

            # store series key dimensions (dimensions other than time)
            seriesKeyDims.push dimId

            # if a dimension has only one value store in separately for display
            if dim.codes.id.length is 1
                data.commonDimensions.push {
                    name: dim.name
                    value: dim.codes[dim.codes.id[0]].name
                }

        # calculate and store multipliers for measure index calculations
        data.dimensions.multipliers = []
        prev = 1
        for dim in data.dimensions.id.slice().reverse()
            data.dimensions.multipliers.push prev
            prev *= data.dimensions[dim].codes.id.length
        data.dimensions.multipliers.reverse()

        # calculate and store multipliers for attribute value index calculations
        for attrId in data.attributes.id
            attr = data.attributes[attrId]
            attr.multipliers = []
            prev = 1
            for dim in attr.dimension.slice().reverse()
                attr.multipliers.push prev
                prev *= data.dimensions[dim].codes.id.length
            attr.multipliers.reverse()

        # calculate multipliers for series key dimensions
        seriesCount = 1
        multipliers = []
        codeLengths = []
        for dim in seriesKeyDims
            multipliers.push seriesCount
            codeLengths.push data.dimensions[dim].codes.id.length
            seriesCount *= data.dimensions[dim].codes.id.length

        # build an array of time series (data is in $scope)
        data.timeseries = []
        for i in [0..seriesCount-1]
            key = []
            for length, j in codeLengths
                codeIndex = Math.floor( i / multipliers[j] ) % length
                key.push codeIndex
            data.timeseries.push createTimeSeries key


    createTimeSeries = (key) ->
        series =
            key: key
            show: false
            keycodes: []
            keynames: []
            attributes: []
            observations: []

        dimensions = $scope.data.dimensions
        for dimId, i in dimensions.seriesKeyDims
            dim = dimensions[dimId]
            code = dim.codes.id[series.key[i]]
            series.keycodes.push code
            continue if dim.codes.id.length is 1 # dim is a common dimension
            series.keynames.push {
                name: dim.name
                value: dim.codes[code].name
            }

        series.attributes = getTimeSeriesAttributes series.key
        series.observations = getTimeSeriesObservations series.key

        series


    getTimeSeriesObservations = (key) ->
        obs = []
        obsIndex = 0
        dimensions = $scope.data.dimensions
        for dimId, i in dimensions.seriesKeyDims
            dimIndex = dimensions[dimId].index
            obsIndex += key[i] * dimensions.multipliers[dimIndex]

        timePeriods = dimensions.timeDimension.codes
        timeMultiplier = dimensions.multipliers[dimensions.timeDimension.index]
        for period, i in timePeriods.id
            index = obsIndex + (i * timeMultiplier)
            obsVal = $scope.data.measure[index]
            continue unless obsVal?
            obs.push {
                date: timePeriods[period].end
                value: obsVal
                attributes: getObservationAttributes(index)
            }
        obs


    getObservationAttributes = (index) ->
        attrs = []
        attributes = $scope.data.attributes
        dimensions = $scope.data.dimensions

        for attrId in attributes.id
            attr = attributes[attrId]
            continue unless attr.dimension.length is dimensions.length
            attrValue = attr.value[index]
            attrValue ?= attr.default
            continue unless attrValue?
            attrValue = attr.codes[attrValue].name if attr.codes?
            attrs.push {name: attr.name, value: attrValue}

        return undefined if attrs.length is 0
        attrs


    getTimeSeriesAttributes = (key) ->
        attrs = []
        attributes = $scope.data.attributes
        dimensions = $scope.data.dimensions

        for attrId in attributes.id 
            attr = attributes[attrId]
            continue if attr.dimension.length is dimensions.id.length
            continue if attr.dimension.length is 0
            index = 0
            for dim, j in attr.dimension
                index += key[dimensions[dim].index] * attr.multipliers[j]
            attrValue = attr.value[index]
            attrValue ?= attr.default
            attrValue = attr.codes[attrValue].name if attr.codes?
            attrs.push {name: attr.name, value: attrValue}

        attrs

#-------------------------------------------------------------------------------
# Code for handling request errors

    onError = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.httpError = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


    onErrorData = (data, status, headers, config) ->
        $scope.state.dataRequestRunning = false
        $scope.state.httpErrorData = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


#-------------------------------------------------------------------------------
# Code for the UI

    $scope.showButtonText = (show) ->
        if show
            return 'Hide'
        else
            return 'Show'


    $scope.changeDimUrl = () ->
        $scope.dimUrl = "#{$scope.wsName}/data/#{$scope.dfName}"
        
        if $scope.key.length
            $scope.dimUrl += "/#{$scope.key}"

        params = []
        params.push "detail=serieskeysonly"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dimUrl += "?" + params.join '&' if params.length

    $scope.changeDimUrl()


    $scope.changeCheckedCodes = () ->
        dimensions = $scope.dimensions
        for dimId in dimensions.id
            dim = dimensions[dimId]
            dim.codes.checked = []
            for codeId in dim.codes.id
                code = dim.codes[codeId]
                dim.codes.checked.push code.id if code.checked

        $scope.changeDataUrl()


    $scope.changeDataUrl = () ->
        $scope.dataUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        key = []
        dimensions = $scope.dimensions
        for dimId, i in dimensions.id
            dim = dimensions[dimId]
            continue if dim.type is 'time'
            key.push dim.codes.checked

        for codes, i in key
            key[i] = codes.join '+'

        $scope.dataUrl += '/' + key.join '.'

        #periods = calculateStartAndEndPeriods dimensions[$scope.dimensions.timeDimension]

        params = []
        #params.push periods if periods.length
        params.push "dimensionAtObservation=AllDimensions"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dataUrl += '?' + params.join '&' if params.length


    calculateStartAndEndPeriods = (timeDimension) ->
        startPeriod = null
        endPeriod = null
        params = ''
        
        for codeId in timeDimension.codes.id
            code = timeDimension.codes[codeId]
            continue unless code.checked

            if startPeriod?
                if code.start < startPeriod.start
                    startPeriod = code
            else
                startPeriod = code

            if endPeriod?
                if endPeriod.end < code.end
                    endPeriod = code
            else
                endPeriod = code

        if startPeriod?
            params = 'startPeriod=' + startPeriod.id

        if endPeriod?
            params += '&endPeriod=' + endPeriod.id

        params


    return
