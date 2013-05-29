demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.3.1'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    $scope.wsName = 'http://live-test-ws-7.nodejitsu.com'
    #$scope.wsName = 'http://localhost:8081'
    #$scope.wsName = 'http://46.137.144.117/FusionCube/ws'
    #$scope.wsName = 'http://46.51.142.127:8080/FusionMatrix3/ws'
    #$scope.wsName = 'http://46.137.144.117/FusionMatrix/ws'

    $scope.dfName = 'ECB_ICP1'
    #$scope.dfName = 'IMF,PGI,1.0'
    #scope.dfName = 'BIS,BISWEB_EERDATAFLOW,1.0'
    #$scope.dfName = 'SDMX,T1,1.0'

    #$scope.key = ''
    #$scope.key = '....'
    #$scope.key = '....A'
    #$scope.key = '...GB'
    #$scope.key = 'ALL'
    #$scope.key = 'M.0+1.0.0.0+1.1+2+3' #D.0.0.0.0.1'
    #$scope.key = 'M.0.0.0.0.3' #D.0.0.0.0.1'
    $scope.key = 'M.AT.N.000000.4.INX'

    $scope.customParams = ''
    #$scope.customParams = 'format=samistat'
    #$scope.customParams = 'lastNObservations=12&outputdates=true'
    #$scope.customParams = 'outputdates=true'

#-------------------------------------------------------------------------------
# Setup test formats

    $scope.dimensions = []
    $scope.results = []
    $scope.formats = ['jsoncodeindex','jsonslice','sdmxjson']

#-------------------------------------------------------------------------------

    fixJsonSlice = (msg) ->
        msg.structure.id = msg.structure.structure
        delete msg.structure.structure

        time = msg.structure.components.TIME_PERIOD
        newTime =
            id: time.id
            name: time.name
            role: 'time'
            values: []

        for key, value of time when key not in ['id','name']
            newTime.values.push value

        msg.structure.components.TIME_PERIOD = newTime
        msg.structure.packaging = msg.structure.components.packaging
        delete msg.structure.components.packaging
        msg.structure.packaging.observationDimensions.push 'TIME_PERIOD'

        pkg = msg.structure.packaging

        comps = {}
        for key, value of msg.structure.components
            comps[key] = value

        msg.structure =
            dataSet:
                dimensions: pkg.dataSetDimensions.map (id) -> comps[id]
                attributes: pkg.dataSetAttributes.map (id) -> comps[id]
            series:
                dimensions: pkg.seriesDimensions.map (id) -> comps[id]
                attributes: pkg.seriesAttributes.map (id) -> comps[id]
            observation:
                dimensions: pkg.observationDimensions.map (id) -> comps[id]
                attributes: pkg.observationAttributes.filter((id)->comps[id]?).map (id) -> comps[id] #OBS_PRE_BREAK
                measures: []

        msg.structure.observation.measures.push
            id: 'OBS_VALUE'
            name: 'Observation value'
            values: []

        msg


    fixJsonCodeIndex = (msg) ->
        msg.measures = []
        msg.measures.push id: 'OBS_VALUE', name: 'Observation value'

        for dim in msg.dimensions
            dim.values = dim.codes
            delete dim.codes

        msg


    fixSdmxJson = (msg) ->
        msg.structure.dimensions.dataSet ?= []
        msg


#-------------------------------------------------------------------------------
# Code for testing crossfilter

    $scope.testCrossfilter = () ->
        sample = crossfilter [
            { name: 'Test1', value: 100 }
            { name: 'Test2', value: 200 }
            { name: 'Test3', value: 300 }
            { name: 'Test4', value: 400 }
            { name: 'Test4_2', value: 400 }
        ]

        nameDim = sample.dimension (d) -> d.name
        valueDim = sample.dimension (d) -> d.value

        sample = crossfilter [
            [ 'Test1', 100 ]
            [ 'Test2', 200 ]
            [ 'Test3', 300 ]
            [ 'Test4', 400 ]
            [ 'Test4_2', 400 ]
        ]

        getFunction = (id) -> (d) -> d[id]

        dims = []
        #dims.push getDim sample, 0
        #dims.push getDim sample, 1
        dims.push sample.dimension getFunction 0
        dims.push sample.dimension getFunction 1
        groups = []
        groups.push dims[0].group()
        groups.push dims[1].group()

        $scope.crossFilterOutput = []
        $scope.crossFilterOutput.push name: 'size', value: sample.size()
        $scope.crossFilterOutput.push name: 'top value', value: dims[1].top(1)[0][1]
        dims[0].filter 'Test2'
        $scope.crossFilterOutput.push name: 'value for Test2', value: dims[1].top(1)[0][1]
        dims[1].filter 400
        $scope.crossFilterOutput.push name: 'filter count', value: dims[1].top(Infinity).length
        dims[0].filter 'Test4'
        $scope.crossFilterOutput.push name: 'filter count', value: dims[1].top(Infinity).length
        $scope.crossFilterOutput.push name: 'group[0] size', value: groups[0].size()
        $scope.crossFilterOutput.push name: 'group[1] size', value: groups[1].size()


#-------------------------------------------------------------------------------
# Code for making requests to the WS

    $scope.getDimensions = () ->

        onError = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = true

            $scope.response =
                status: status
                errors: data.errors


        onResults = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = false

            data = fixJsonSlice data

            pkg = data.structure.packaging
            pkg.dataSetDimensions ?= []
            pkg.seriesDimensions ?= []
            pkg.observationDimensions ?= []
            dims = pkg.dataSetDimensions.concat pkg.seriesDimensions, pkg.observationDimensions
            componentMap = {}
            data.structure.components.forEach (c) -> componentMap[c.id] = c
            $scope.dimensions = []

            for dimId in dims
                dim = componentMap[dimId]
                codes = []
                for value in dim.values
                    codes.push value.id
                $scope.dimensions.push { id: dimId, name: dim.name, codes: codes.join(', ') }

        config =
            method: 'GET'
            url: "#{$scope.wsName}/data/#{$scope.dfName}/ALL?format=jsonslice&detail=seriesKeysOnly" #lastNObservations=12"
            cache: false

        $scope.state.httpError = false
        $scope.state.testRunning = true
        $http(config).success(onResults).error(onError)


    $scope.runTest = (format) ->
        start = (new Date).getTime()
        if window?.performance?.memory?
            startMem = window.performance.memory.usedJSHeapSize

        result =
            format: format
        $scope.results.push result

        transformResponse = (data) -> data

        onResults = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = false

            $scope.response =
                status: status

            result.requestTime = ((new Date).getTime() - start) + ' ms'
            result.responseSize = bytesToSize unescape(encodeURIComponent(data.length)), 2

            start = (new Date).getTime()
            json = JSON.parse data
            result.parseTime = ((new Date).getTime() - start) + ' ms'

            if window?.performance?.memory?
                result.memory = window.performance.memory.usedJSHeapSize - startMem

            start = (new Date).getTime()
            cube = switch result.format
                when 'jsonslice' then new JSONSliceCube json
                when 'jsoncodeindex' then new JSONCodeIndexCube json, false, true
                when 'sdmxjson' then new SDMXJsonCube json
            result.initTime = ((new Date).getTime() - start) + ' ms'

            result.actualObsCount = cube.obsCount()
            result.dataChecksum = cube.checkSum()

            start = (new Date).getTime()
            result.simpleArrayChecksum = testFlattenResults cube, result
            result.flattenToSimpleArray = ((new Date).getTime() - start) + ' ms'

            start = (new Date).getTime()
            result.complexArrayChecksum = testFlattenResultsWithReferences cube, result
            result.flattenToComplexArray = ((new Date).getTime() - start) + ' ms'

            start = (new Date).getTime()
            result.cellAccessChecksum = testCellAccess cube, result
            result.cellAccess = ((new Date).getTime() - start) + ' ms'

        onError = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = true

            $scope.response =
                status: status
                errors: data.errors

        config =
            method: 'GET'
            url: getTestUrl format
            transformResponse: transformResponse
            cache: false

        $scope.state.httpError = false
        $scope.state.testRunning = true
        $http(config).success(onResults).error(onError)

#-------------------------------------------------------------------------------
# Objects for the different formats

    class JSONSliceCube
        constructor: (@msg) ->
            @msg = fixJsonSlice @msg

        observations: () =>
            obs = []
            for ds in @msg.dataSets
                ds.dimensions ?= []
                if ds.observations?
                    for o in ds.observations
                        obs.push ds.dimensions.concat o
                else
                    for s in ds.series
                        for o in s.observations
                            obs.push ds.dimensions.concat s.dimensions, o
            obs

        observationsWithReferences: () =>
            str = @msg.structure
            obs = []
            for ds in @msg.dataSets
                ds.dimensions ?= []
                dsDimMap = ds.dimensions.map (v, i) -> str.dataSet.dimensions[i].values[v]
                if ds.observations?
                    for o in ds.observations
                        obs.push dsDimMap.concat o
                else
                    for s in ds.series
                        serMap = s.dimensions.map (v, i) -> str.series.dimensions[i].values[v]
                        for o in s.observations
                            t = []
                            for v, i in str.observation.dimensions
                                t[i] = str.observation.dimensions[i].values[o[i]]
                            t.push o[str.observation.dimensions.length]
                            obs.push dsDimMap.concat serMap, t
            obs

        components: () =>
            str = @msg.structure
            str.dataSet.dimensions.concat str.series.dimensions,
                str.observation.dimensions,
                str.observation.measures,
                str.observation.attributes

        dimensions: () ->
            str = @msg.structure
            str.dataSet.dimensions.concat str.series.dimensions, str.observation.dimensions

        observation: (key) ->
            return @index[ key.join ':'] if @index?

            @index = {}
            oDims = @msg.structure.observation.dimensions.length
            for ds in @msg.dataSets
                if ds.observations?
                    for o in ds.observations
                        @index[ ds.dimensions.concat(o.slice(0,oDims)).join ':' ] = o[oDims]
                else
                    for s in ds.series
                        for o in s.observations
                            @index[ ds.dimensions.concat(s.dimensions, o.slice(0,oDims)).join ':' ] = o[oDims]

            return @index[ key.join ':'] if @index?



            str = @msg.structure
            dDims = key.slice 0, str.dataSet.dimensions.length
            sDims = key.slice dDims.length, dDims.length + str.series.dimensions.length
            oDims = key.slice dDims.length + sDims.length
            for ds in @msg.dataSets
                continue unless ds.dimensions.every (d,i) -> d is dDims[i]
                if ds.observations?
                else
                    for series in ds.series
                        continue unless series.dimensions.every (d,i) -> d is sDims[i]
                        for obs in series.observations
                            continue unless oDims.every (d,i) -> d is obs[i]
                            return obs[oDims.length]
            null

        obsCount: ()->
            reduceSeries = (t, s) -> t + s.observations.length

            reduceDataSets = (t, d) ->
                if d.observations?
                    t + d.observations.reduce reduceObservations, 0
                else
                    t + d.series.reduce reduceSeries, 0

            @msg.dataSets.reduce reduceDataSets, 0

        checkSum: ()->
            obsValueIndex = @msg.structure.observation.dimensions.length

            reduceObservations = (t, o) =>
                value = o[obsValueIndex]
                if value? then t + value else t

            reduceSeries = (t, s) -> t + s.observations.reduce reduceObservations, 0

            reduceDataSets = (t, d) ->
                if d.observations?
                    t + d.observations.reduce reduceObservations, 0
                else
                    t + d.series.reduce reduceSeries, 0

            @msg.dataSets.reduce reduceDataSets, 0

#-------------------------------------------------------------------------------

    class JSONCodeIndexCube
        constructor: (@msg) ->
            @msg = fixJsonCodeIndex @msg

        observations: () ->
            obs = []
            for key in Object.keys @msg.data
                dims = key.split ':'
                dims.push @msg.data[key]
                obs.push dims
            obs

        observationsWithReferences: () ->
            obs = []
            for key in Object.keys @msg.data
                o = []
                for v, i in key.split ':'
                    o.push @msg.dimensions[i].values[v]
                o.push @msg.data[key]
                obs.push o
            obs

        components: () ->
            @msg.dimensions.concat @msg.measures

        dimensions: () ->
            @msg.dimensions.slice()

        observation: (key) ->
            @msg.data[ key.join ':' ]

        checkSum: ()->
            sum = 0
            for key in Object.keys @msg.data
                sum += @msg.data[key]
            sum

        obsCount: ()->
            Object.keys(@msg.data).length


#-------------------------------------------------------------------------------

    class SDMXJsonCube
        constructor: (@msg) ->
            @msg = fixSdmxJson @msg

        observations: () ->
            obs = []
            dsDims = @msg.structure.dimensions.dataSet.map( (d) -> 0 )

            for ds in @msg.dataSets
                if ds.series
                    for key, value of ds.series
                        serDims = dsDims.concat key.split ':'
                        for key2, value2 of value.observations
                            dims = serDims.concat key2.split ':'
                            obs.push dims.concat value2[0..0]
                else
                    for key, value of ds.observations
                        dims = dsDims.concat key.split ':'
                        obs.push dims.concat value[0..0]

            obs

        observationsWithReferences: () ->
            obs = []
            dsDims = @msg.structure.dimensions.dataSet.map( (d) -> d.values[0] )
            dims = @msg.structure.dimensions

            for ds in @msg.dataSets
                if ds.series
                    for key, value of ds.series
                        serDims = dsDims.concat key.split(':').map( (v,i) -> dims.series[i].values[v] )
                        for key2, value2 of value.observations
                            obsDims = serDims.concat key2.split(':').map( (v,i) -> dims.observation[i].values[v] )
                            obs.push obsDims.concat value2[0..0]
                else
                    for key, value of ds.observations
                        obsDims = dsDims.concat key.split(':').map( (v,i) -> dims.observation[i].values[v] )
                        obs.push obsDims.concat value[0..0]

            obs

        components: () ->
            str = @msg.structure
            str.dimensions.dataSet.concat str.dimensions.series,
                str.dimensions.observation,
                str.attributes.dataSet,
                str.attributes.series,
                str.attributes.observation

        dimensions: () ->
            str = @msg.structure
            str.dimensions.dataSet.concat str.dimensions.series, str.dimensions.observation

        observation: (key) ->
            dataSetDims = @msg.structure.dimensions.dataSet.length
            seriesDims = @msg.structure.dimensions.series.length

            dataSetKey = key[0...dataSetDims].join ':'
            seriesKey = key[dataSetDims...(dataSetDims+seriesDims)].join ':'
            obsKey = key[(dataSetDims+seriesDims)...].join ':'

            obs = undefined
            for ds in @msg.dataSets
                if ds.series
                    obs = ds.series[seriesKey]?.observations[obsKey]
                    return obs[0] if obs?
                else
                    obs = ds.observations[obsKey]
                    return obs[0] if obs?

            obs

        checkSum: () ->
            sum = 0
            for ds in @msg.dataSets
                if ds.series
                    for key, value of ds.series
                        for key2, value2 of value.observations
                            sum += value2[0] if value2[0]?
                else
                    for key, value of ds.observations
                        sum += value[0] if value[0]?
            sum

        obsCount: () ->
            count = 0
            for ds in @msg.dataSets
                if ds.series
                    for key, value of ds.series
                        count += Object.keys(value.observations).length
                else
                    count += Object.keys(ds.observations).length
            count

#-------------------------------------------------------------------------------
# Tests

    testFlattenResults = (cube, result) ->
        dimensions = cube.dimensions()

        obsValueIndex = dimensions.length

        result.obsCount = 1
        result.obsCount *= c.values.length for c, i in dimensions

        obs = cube.observations()
        result.simpleArrayLength = obs.length
        checkSum = obs.reduce( ( (i, o) -> i + o[obsValueIndex] ), 0 )

        result.density = (result.actualObsCount / result.obsCount).toFixed 2

        checkSum


    testFlattenResultsWithReferences = (cube, result) ->
        dimensions = cube.dimensions()

        obsValueIndex = dimensions.length

        result.obsCount = 1
        result.obsCount *= c.values.length for c, i in dimensions

        obs = cube.observationsWithReferences()
        result.complexArrayLength = obs.length
        checkSum = obs.reduce( ( (i, o) -> i + o[obsValueIndex] ), 0 )

        checkSum


    testCellAccess = (cube, result) ->
        dimensions = cube.dimensions()

        obsCount = 1
        multipliers = []
        codeLengths = []
        prev = 1
        for dim in dimensions.slice().reverse()
            multipliers.push prev
            obsCount *= dim.values.length
            codeLengths.push dim.values.length
            prev *= dim.values.length
        multipliers.reverse()
        codeLengths.reverse()

        checkSum = 0
        missing = 0
        for i in [0..obsCount-1]
            key = []
            for length, j in codeLengths
                key.push Math.floor( i / multipliers[j] ) % length

            obs = cube.observation(key)

            if not obs?
                missing += 1
                continue

            checkSum += obs

        checkSum


#-------------------------------------------------------------------------------
# Helpers

    bytesToSize = (bytes, precision) ->
        kilobyte = 1024
        megabyte = kilobyte * 1024
        gigabyte = megabyte * 1024
        terabyte = gigabyte * 1024

        if bytes >= 0 and bytes < kilobyte
            return bytes + ' B'

        else if bytes >= kilobyte and bytes < megabyte
            return (bytes / kilobyte).toFixed(precision) + ' KB'

        else if bytes >= megabyte and bytes < gigabyte
            return (bytes / megabyte).toFixed(precision) + ' MB'

        else if bytes >= gigabyte and bytes < terabyte
            return (bytes / gigabyte).toFixed(precision) + ' GB'

        else if bytes >= terabyte
            return (bytes / terabyte).toFixed(precision) + ' TB'

        else
            return bytes + ' B'


#-------------------------------------------------------------------------------
# Code for the UI


    getTestUrl = (format) ->
        testUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        if $scope.key.length
            testUrl += "/#{$scope.key}"

        params = []
        params.push $scope.customParams if $scope.customParams.length
        #params.push 'format=' + format.split('_')[0]
        testUrl += "?" + params.join '&' if params.length
        $scope.url = testUrl
        testUrl

    return
